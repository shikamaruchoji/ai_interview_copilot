import 'package:flutter_test/flutter_test.dart';

import 'package:ai_interview_copilot/src/services/question_detector.dart';
import 'package:ai_interview_copilot/src/services/rag_service.dart';

void main() {
  group('QuestionDetector', () {
    test('hasQuestionShape detects ? and common openers', () {
      expect(QuestionDetector.hasQuestionShape('What is your name?'), isTrue);
      expect(QuestionDetector.hasQuestionShape('Tell me about yourself'), isTrue);
      expect(QuestionDetector.hasQuestionShape('Hello there'), isFalse);
      expect(QuestionDetector.hasQuestionShape(''), isFalse);
    });

    test('emits question after pause', () async {
      final qd = QuestionDetector(pause: const Duration(milliseconds: 80));
      final future = qd.onQuestion.first;
      qd.updateTranscript('How do you handle deadlines?');
      final q = await future.timeout(const Duration(seconds: 2));
      expect(q, 'How do you handle deadlines?');
      await qd.dispose();
    });

    test('finalResult uses shorter wait path', () async {
      final qd = QuestionDetector(pause: const Duration(milliseconds: 500));
      final buf = <String>[];
      final sub = qd.onQuestion.listen(buf.add);
      qd.updateTranscript('Why Flutter?', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(buf, isNotEmpty);
      expect(buf.first, 'Why Flutter?');
      await sub.cancel();
      await qd.dispose();
    });

    test('suppress blocks transcript updates and forceFinalize', () async {
      final qd = QuestionDetector(pause: const Duration(milliseconds: 80));
      final buf = <String>[];
      final sub = qd.onQuestion.listen(buf.add);
      qd.updateTranscript('What is your approach to testing?');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(buf, hasLength(1));
      qd.clearLastEmitted();
      qd.suppress();
      qd.updateTranscript('How do you prioritize bugs?');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(buf, hasLength(1));
      qd.forceFinalize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(buf, hasLength(1));
      qd.releaseSuppress();
      qd.updateTranscript('Why Kotlin?');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(buf.length, greaterThanOrEqualTo(2));
      await sub.cancel();
      await qd.dispose();
    });

    test('clearLastEmitted allows same text to emit again', () async {
      final qd = QuestionDetector(pause: const Duration(milliseconds: 80));
      final buf = <String>[];
      final sub = qd.onQuestion.listen(buf.add);
      qd.updateTranscript('What is your stack?');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(buf, hasLength(1));
      qd.clearLastEmitted();
      qd.updateTranscript('What is your stack?');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(buf, hasLength(2));
      await sub.cancel();
      await qd.dispose();
    });
  });

  group('RagService', () {
    test('retrieve returns resume-tagged chunks for query', () {
      final rag = RagService.fromTexts(
        'I built mobile apps with Flutter and Dart for two years.',
        'We need Kotlin and Android experience.',
      );
      final hits = rag.retrieve('Tell me about Flutter', k: 3);
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.contains('Flutter')), isTrue);
    });
  });
}
