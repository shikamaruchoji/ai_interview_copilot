import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../services/question_detector.dart';
import '../widgets/section_card.dart';

/// After a question is detected, keep the mic off this long so your own practice answer
/// is not transcribed (which re-triggers question detection).
const _kPracticePauseAfterAnswer = Duration(seconds: 38);

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final SpeechToText _speech = SpeechToText();
  final QuestionDetector _detector = QuestionDetector();
  StreamSubscription<String>? _qSub;

  bool _listening = false;
  bool _sessionActive = false;
  bool _resumeListenScheduled = false;
  bool _speechReady = false;
  String? _err;
  AppState? _app;

  /// Mic off + detector frozen while you read the suggestion / practice out loud.
  bool _micPausedForPractice = false;
  Timer? _resumeMicAfterPracticeTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _app = context.read<AppState>();
      _qSub?.cancel();
      _qSub = _detector.onQuestion.listen((q) {
        final app = _app;
        if (app == null) return;
        unawaited(_onQuestionDetected(q, app));
      });
    });
  }

  void _cancelPracticeResumeTimer() {
    _resumeMicAfterPracticeTimer?.cancel();
    _resumeMicAfterPracticeTimer = null;
  }

  Future<void> _pauseMicForPracticePhase() async {
    if (!mounted) return;
    _cancelPracticeResumeTimer();
    _resumeListenScheduled = false;
    _micPausedForPractice = true;
    _detector.suppress();
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _schedulePracticePhaseEnd() {
    _cancelPracticeResumeTimer();
    _resumeMicAfterPracticeTimer = Timer(_kPracticePauseAfterAnswer, () {
      unawaited(_resumeMicAfterPracticePhase());
    });
  }

  Future<void> _resumeMicAfterPracticePhase() async {
    _cancelPracticeResumeTimer();
    if (!_sessionActive || !mounted) return;
    _micPausedForPractice = false;
    _detector.releaseSuppress();
    if (mounted) setState(() {});
    if (!_sessionActive || !_speechReady || !_listening) return;
    if (_speech.isListening) return;
    try {
      await _startSpeechListen();
    } catch (e) {
      if (mounted) setState(() => _err = 'Could not resume listening: $e');
    }
  }

  void _listenNowSkipPause() {
    if (!_micPausedForPractice) return;
    unawaited(_resumeMicAfterPracticePhase());
  }

  Future<void> _onQuestionDetected(String q, AppState app) async {
    await _pauseMicForPracticePhase();
    try {
      await app.answerQuestion(q);
    } finally {
      if (mounted) _detector.clearLastEmitted();
    }
    if (!mounted || !_sessionActive) return;
    _schedulePracticePhaseEnd();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (s) {
          if (mounted) setState(() {});
          _onSpeechStatus(s);
        },
        onError: (e) {
          if (mounted) setState(() => _err = e.errorMsg);
        },
      );
      if (mounted) setState(() => _speechReady = ok);
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  void _onSpeechStatus(String status) {
    if (_micPausedForPractice) return;
    if (!_sessionActive || !mounted || !_speechReady) return;
    if (status == SpeechToText.listeningStatus) return;
    if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus ||
        status == 'doneNoResult') {
      _scheduleResumeListen();
    }
  }

  void _scheduleResumeListen() {
    if (_micPausedForPractice) return;
    if (!_sessionActive || !mounted || _resumeListenScheduled) return;
    if (_speech.isListening) return;
    _resumeListenScheduled = true;
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _resumeListenScheduled = false;
      if (_micPausedForPractice || !_sessionActive || !mounted) return;
      if (_speech.isListening) return;
      try {
        await _startSpeechListen();
      } catch (e) {
        if (mounted) setState(() => _err = 'Could not resume listening: $e');
      }
    });
  }

  Future<void> _startSpeechListen() async {
    if (_micPausedForPractice) return;
    await _speech.listen(
      onResult: _handleSpeechResult,
      listenFor: const Duration(hours: 8),
      pauseFor: const Duration(seconds: 45),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult res) {
    if (!mounted || _micPausedForPractice) return;
    final text = res.recognizedWords.trim();
    if (text.isEmpty) return;
    final app = context.read<AppState>();
    app.updateInterviewerText(text);
    _detector.updateTranscript(text, isFinal: res.finalResult);
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    setState(() {
      _err = null;
      _listening = true;
    });
    app.resetLive();
    await app.prepareInterview();
    _cancelPracticeResumeTimer();
    _micPausedForPractice = false;
    _detector.releaseSuppress();
    _detector.reset();

    if (!_speechReady) {
      setState(() {
        _listening = false;
        _err =
            'Speech recognition unavailable. Check microphone permission and try again.';
      });
      return;
    }

    _sessionActive = true;
    try {
      await _startSpeechListen();
    } catch (e) {
      _sessionActive = false;
      if (mounted) {
        setState(() {
          _listening = false;
          _err = e.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    _sessionActive = false;
    _resumeListenScheduled = false;
    _cancelPracticeResumeTimer();
    _micPausedForPractice = false;
    _detector.releaseSuppress();
    await _speech.stop();
    _detector.reset();
    if (mounted) setState(() => _listening = false);
  }

  @override
  void dispose() {
    _cancelPracticeResumeTimer();
    _qSub?.cancel();
    _speech.stop();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Mode'),
        actions: [
          TextButton(
            onPressed: () => context.read<AppState>().logout(),
            child: const Text('Logout'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _listening ? null : _start,
                    child: const Text('Start Interview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_listening ? null : _stop,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ListeningPill(
                  sessionActive: _listening,
                  micPausedForPractice: _micPausedForPractice,
                  speechListening: _speech.isListening,
                ),
                const Spacer(),
                if (!_speechReady)
                  Text(
                    'Speech unavailable',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (s.lastLatencyMs > 0)
                  Text('Latency: ${s.lastLatencyMs}ms', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (_micPausedForPractice) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _listenNowSkipPause,
                  icon: const Icon(Icons.mic, size: 18),
                  label: const Text('Listen now (interviewer speaking)'),
                ),
              ),
            ],
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SectionCard(
                      title: 'Live transcript',
                      subtitle: _micPausedForPractice
                          ? 'Mic paused so your practice answer is not picked up. Tap “Listen now” when the interviewer talks again.'
                          : 'Device speech-to-text — pause briefly after their question to get a suggestion.',
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SingleChildScrollView(
                          child: Text(
                            s.interviewerText.isEmpty ? '…' : s.interviewerText,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SectionCard(
                      title: 'Suggested answer',
                      subtitle: 'Fuller answers (several sentences). Mic stays off briefly after each suggestion.',
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.generatingAnswer
                                    ? 'Generating answer…'
                                    : (s.suggestedAnswer.isEmpty
                                        ? '…'
                                        : s.suggestedAnswer),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (s.lastAnswerError != null &&
                                  !s.generatingAnswer) ...[
                                const SizedBox(height: 8),
                                Text(
                                  s.lastAnswerError!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.orangeAccent),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningPill extends StatelessWidget {
  const _ListeningPill({
    required this.sessionActive,
    required this.micPausedForPractice,
    required this.speechListening,
  });

  final bool sessionActive;
  final bool micPausedForPractice;
  final bool speechListening;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color c;
    if (!sessionActive) {
      label = 'Idle';
      c = Colors.white38;
    } else if (micPausedForPractice) {
      label = 'Paused — practice answer';
      c = Colors.amberAccent;
    } else if (speechListening) {
      label = 'Listening…';
      c = Colors.greenAccent;
    } else {
      label = 'Connecting…';
      c = Colors.lightBlueAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c),
      ),
    );
  }
}
