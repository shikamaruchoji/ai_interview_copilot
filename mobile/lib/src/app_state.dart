import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/document_parser.dart';
import 'services/local_profile_store.dart';
import 'services/gemini_answer_service.dart';
import 'services/rag_service.dart';

class AppState extends ChangeNotifier {
  static const _kProfileId = 'profile_id';

  final LocalProfileStore _store = LocalProfileStore();

  bool ready = false;
  String? profileId;

  bool hasResume = false;
  bool hasJob = false;

  bool get setupComplete => hasResume && hasJob;

  RagService? _rag;
  final List<String> shortTermMemory = [];

  String interviewerText = '';
  String suggestedAnswer = '';
  int lastLatencyMs = 0;
  bool generatingAnswer = false;
  String? lastAnswerError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    profileId = prefs.getString(_kProfileId);
    if (profileId != null) {
      await refreshSetupStatus();
      await _refreshRag();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _refreshRag() async {
    if (profileId == null) return;
    final resume = await _store.readResumeText(profileId!);
    final job = await _store.readJobText(profileId!);
    _rag = RagService.fromTexts(resume, job);
  }

  Future<void> prepareInterview() async {
    await _refreshRag();
    shortTermMemory.clear();
    notifyListeners();
  }

  Future<void> loginWithPin(String pin) async {
    final id = await _store.profileIdForPin(pin.trim());
    profileId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileId, id);
    await refreshSetupStatus();
    await _refreshRag();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfileId);
    profileId = null;
    hasResume = false;
    hasJob = false;
    _rag = null;
    shortTermMemory.clear();
    notifyListeners();
  }

  Future<void> refreshSetupStatus() async {
    if (profileId == null) return;
    final st = await _store.setupFlags(profileId!);
    hasResume = st.hasResume;
    hasJob = st.hasJob;
    notifyListeners();
  }

  Future<void> saveResumeFromFile(File file) async {
    final text = await extractDocumentText(file);
    await _store.saveResumeText(profileId!, text);
    await refreshSetupStatus();
    await _refreshRag();
  }

  Future<void> saveJobFromText(String text) async {
    await _store.saveJobText(profileId!, text);
    await refreshSetupStatus();
    await _refreshRag();
  }

  Future<void> saveJobFromFile(File file) async {
    final text = await extractDocumentText(file);
    await _store.saveJobText(profileId!, text);
    await refreshSetupStatus();
    await _refreshRag();
  }

  Future<void> setGeminiApiKey(String key) async {
    await _store.setGeminiApiKey(key);
    notifyListeners();
  }

  Future<String?> getGeminiApiKey() => _store.geminiApiKey();

  Future<void> answerQuestion(String question) async {
    if (profileId == null) return;
    lastAnswerError = null;
    generatingAnswer = true;
    notifyListeners();

    try {
      final sw = Stopwatch()..start();
      final retrieved = _rag?.retrieve(question, k: 6) ?? <String>[];
      final key = await _store.geminiApiKey();

      String ans;
      try {
        if (key != null && key.isNotEmpty) {
          final svc = GeminiAnswerService(apiKey: key);
          ans = await svc
              .generate(
                question: question,
                retrievedChunks: retrieved,
                shortMemory: shortTermMemory.toList(),
              )
              .timeout(
                const Duration(seconds: 35),
                onTimeout: () => fallbackAnswer(question, retrieved),
              );
        } else {
          ans = fallbackAnswer(question, retrieved);
        }
      } catch (e) {
        lastAnswerError = e.toString();
        ans = fallbackAnswer(question, retrieved);
      }

      sw.stop();
      suggestedAnswer = ans;
      lastLatencyMs = sw.elapsedMilliseconds;
      shortTermMemory.add('Q: $question');
      shortTermMemory.add('A: $ans');
      if (shortTermMemory.length > 6) {
        shortTermMemory.removeRange(0, shortTermMemory.length - 6);
      }
    } finally {
      generatingAnswer = false;
      notifyListeners();
    }
  }

  void updateInterviewerText(String text) {
    interviewerText = text;
    notifyListeners();
  }

  void resetLive() {
    interviewerText = '';
    suggestedAnswer = '';
    lastLatencyMs = 0;
    generatingAnswer = false;
    lastAnswerError = null;
    shortTermMemory.clear();
    notifyListeners();
  }
}
