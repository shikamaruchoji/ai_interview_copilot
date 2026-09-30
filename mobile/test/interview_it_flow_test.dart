import 'package:flutter_test/flutter_test.dart';

import 'package:ai_interview_copilot/src/services/gemini_answer_service.dart';
import 'package:ai_interview_copilot/src/services/interview_prompt.dart';
import 'package:ai_interview_copilot/src/services/question_detector.dart';
import 'package:ai_interview_copilot/src/services/rag_service.dart';

/// Realistic IT interview strings — verifies detection, RAG, prompts, and offline fallback
/// behave like a live copilot (answer the question, not dump résumé text).
void main() {
  const resume =
      'Senior software engineer, 6 years. Led migration of monolith to microservices on Kubernetes. '
      'Stack: Dart, Flutter, Go, PostgreSQL, Redis, gRPC. Reduced p99 latency 40 percent.';
  const job =
      'Looking for backend engineer with distributed systems, observability, and on-call experience.';

  final itQuestions = <String>[
    'How would you debug a sudden spike in p99 latency on a production API?',
    'Walk me through how you would roll out a breaking change to a microservice safely.',
    'What trade-offs do you see between JWTs and opaque session tokens for a B2B SaaS API?',
    'How do you approach database schema changes when you have zero-downtime requirements?',
    'Explain how you would investigate an intermittent 500 error that only shows under load.',
  ];

  group('IT questions → question shape', () {
    for (final q in itQuestions) {
      test('detects interview shape: ${q.substring(0, 32)}…', () {
        expect(QuestionDetector.hasQuestionShape(q), isTrue);
      });
    }
  });

  group('IT questions → RAG returns tagged snippets', () {
    late RagService rag;
    setUp(() {
      rag = RagService.fromTexts(resume, job);
    });

    for (final q in itQuestions) {
      test('retrieve non-empty for: ${q.substring(0, 40)}…', () {
        final hits = rag.retrieve(q, k: 4);
        expect(hits, isNotEmpty);
        expect(hits.every((h) => h.startsWith('[RESUME]') || h.startsWith('[JOB]')), isTrue);
      });
    }
  });

  group('Gemini user prompt (no network)', () {
    test('embeds full question and does not treat snippets as the only task', () {
      final q = itQuestions[0];
      final rag = RagService.fromTexts(resume, job);
      final hits = rag.retrieve(q, k: 3);
      final body = buildGeminiUserPrompt(
        question: q,
        retrievedChunks: hits,
        shortMemory: const ['Q: prior?', 'A: prior bullet'],
      );
      expect(body, contains('INTERVIEW_QUESTION'));
      expect(body, contains(q));
      expect(body, contains('RESUME_AND_JOB_SNIPPETS'));
      expect(body, contains('[RESUME]'));
    });

    test('system prompt asks to answer the question in first person', () {
      expect(geminiInterviewSystemPrompt.toLowerCase(), contains('first person'));
      expect(geminiInterviewSystemPrompt.toLowerCase(), contains('do not paste'));
    });
  });

  group('Offline fallback answers IT intent (not raw chunk paste)', () {
    test('debug / latency question → structured bullets, no huge excerpt', () {
      final rag = RagService.fromTexts(resume, job);
      final hits = rag.retrieve(itQuestions[0], k: 6);
      final out = fallbackAnswer(itQuestions[0], hits);
      expect(out, startsWith('•'));
      expect(out.split('\n').where((l) => l.trim().startsWith('•')).length, greaterThanOrEqualTo(3));
      expect(out.length, lessThan(1200));
      expect(out.contains('[RESUME]'), isFalse);
    });

    test('microservice rollout question → rollout-focused bullets', () {
      final out = fallbackAnswer(
        'How would you deploy a change across ten microservices on Kubernetes?',
        const ['[RESUME] $resume'],
      );
      expect(out.toLowerCase(), contains('deploy'));
      expect(out.toLowerCase(), contains('health'));
    });

    test('generic IT question with no retrieval → still three actionable bullets', () {
      final out = fallbackAnswer('What is CAP theorem and when does it matter?', []);
      expect(out.split('•').length, greaterThanOrEqualTo(4));
    });
  });

  group('QuestionDetector emits after pause (IT phrasing)', () {
    test('emits for behavioral IT question', () async {
      final qd = QuestionDetector(pause: const Duration(milliseconds: 80));
      final future = qd.onQuestion.first;
      qd.updateTranscript(
        'Tell me about a time you had to fix a serious production incident — what was your first step?',
      );
      final q = await future.timeout(const Duration(seconds: 2));
      expect(q, contains('production incident'));
      await qd.dispose();
    });
  });
}
