import 'dart:async';

/// Emits a finalized question after speech/text stops updating for [pause].
class QuestionDetector {
  QuestionDetector({this.pause = const Duration(milliseconds: 750)});

  final Duration pause;
  final _ctl = StreamController<String>.broadcast();
  Timer? _timer;
  String _lastText = '';
  String _lastEmitted = '';
  bool _suppress = false;

  /// While true, [updateTranscript] / [forceFinalize] do nothing (mic off during your answer).
  bool get isSuppressed => _suppress;

  void suppress() {
    _timer?.cancel();
    _suppress = true;
  }

  void releaseSuppress() {
    _suppress = false;
  }

  /// Interview-style prompts: question mark OR common interrogative / request openers.
  static final _qHint = RegExp(
    r'.*('
    r'\?'
    r'|(^|\s)('
    r'what|why|how|when|where|who|which'
    r'|tell me|tell us|tell me about|tell us about'
    r'|walk me|walk us|walk me through|walk us through'
    r'|could you|can you|would you|will you|should you'
    r'|describe|explain|share|discuss|outline'
    r'|talk through|talk me through|run me through|give me'
    r'|walk through|go through'
    r'|introduce|introduce yourself'
    r'|have you|did you|are you|is there|do you|were you'
    r'|whats|what is|what are|what was|what were'
    r')\b).*',
    caseSensitive: false,
  );

  /// If true, always feed the question pipeline (even when voice-gate says "you").
  static bool hasQuestionShape(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    return _qHint.hasMatch(t);
  }

  Stream<String> get onQuestion => _ctl.stream;

  void updateTranscript(String text, {bool isFinal = false}) {
    if (_suppress) return;
    final t = text.trim();
    if (t.isEmpty) return;
    _lastText = t;
    _timer?.cancel();
    final wait = isFinal ? const Duration(milliseconds: 450) : pause;
    _timer = Timer(wait, _maybeEmit);
  }

  void forceFinalize() {
    if (_suppress) return;
    _timer?.cancel();
    _maybeEmit();
  }

  void _maybeEmit() {
    final candidate = _lastText.trim();
    if (candidate.isEmpty) return;
    if (!_qHint.hasMatch(candidate)) return;
    if (candidate == _lastEmitted) return;
    _lastEmitted = candidate;
    _ctl.add(candidate);
  }

  void reset() {
    _timer?.cancel();
    _lastText = '';
    _lastEmitted = '';
    _suppress = false;
  }

  /// Call after an answer is produced so the same transcript can trigger a new question later.
  void clearLastEmitted() {
    _lastEmitted = '';
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _ctl.close();
  }
}
