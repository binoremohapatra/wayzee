import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/voice/speech_recognizer_service.dart';

void main() {
  group('SpeechRecognizerService Tests', () {
    test('FakeRecognizer: initialize succeeds', () async {
      final recognizer = FakeRecognizer(immediate: true);
      await recognizer.initialize();
      expect(recognizer.isListening, isFalse);
      await recognizer.dispose();
    });

    test('FakeRecognizer: listen returns scripted results', () async {
      final results = [
        RecognitionResult(
          text: 'take me to library',
          alternatives: ['go to library', 'library'],
          confidence: 0.9,
          isFinal: true,
        ),
      ];
      final recognizer = FakeRecognizer(
        scriptedResults: results,
        immediate: true,
      );
      await recognizer.initialize();

      final stream = recognizer.listen();
      final result = await stream.first;

      expect(result.text, equals('take me to library'));
      expect(result.confidence, equals(0.9));
      expect(result.isFinal, isTrue);

      await recognizer.dispose();
    });

    test('FakeRecognizer: simulate low confidence', () async {
      final results = [
        RecognitionResult(
          text: 'take me to library',
          alternatives: ['go to library'],
          confidence: 0.9,
          isFinal: true,
        ),
      ];
      final recognizer = FakeRecognizer(
        scriptedResults: results,
        simulateLowConfidence: true,
        immediate: true,
      );
      await recognizer.initialize();

      final stream = recognizer.listen();
      final result = await stream.first;

      expect(result.confidence, lessThan(0.5));

      await recognizer.dispose();
    });

    test('FakeRecognizer: simulate silence', () async {
      final recognizer = FakeRecognizer(
        simulateSilence: true,
        immediate: true,
      );
      await recognizer.initialize();

      final stream = recognizer.listen(maxDuration: const Duration(seconds: 1));
      final results = await stream.toList();

      expect(results, isEmpty);

      await recognizer.dispose();
    });

    test('FakeRecognizer: simulate error', () async {
      final recognizer = FakeRecognizer(
        simulateError: true,
        errorType: RecognitionError.noPermission,
        immediate: true,
      );
      await recognizer.initialize();

      expect(
        () => recognizer.listen().first,
        throwsA(isA<Exception>()),
      );

      await recognizer.dispose();
    });

    test('FakeRecognizer: stop stops listening', () async {
      final recognizer = FakeRecognizer(
        immediate: true,
      );
      await recognizer.initialize();

      recognizer.listen();
      expect(recognizer.isListening, isTrue);

      await recognizer.stop();
      expect(recognizer.isListening, isFalse);

      await recognizer.dispose();
    });
  });
}
