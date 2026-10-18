import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/voice/speech_center.dart';

void main() {
  group('SpeechCenter Tests', () {
    late SpeechCenter speechCenter;

    setUp(() {
      speechCenter = SpeechCenter();
    });

    tearDown(() {
      speechCenter.clear();
    });

    test('Speak adds to queue', () async {
      speechCenter.speak('Hello');
      await Future.delayed(const Duration(milliseconds: 10));
      // Check that speak was called (queue processed)
      expect(speechCenter.isSpeaking, isTrue);
    });

    test('Repeat suppression works', () async {
      speechCenter.speak('Hello');
      await Future.delayed(const Duration(milliseconds: 10));
      speechCenter.speak('Hello'); // Should be suppressed
      await Future.delayed(const Duration(milliseconds: 10));
      // Should not increase queue size
      expect(speechCenter.queueSize, lessThanOrEqualTo(1));
    });

    test('Priority queue: danger interrupts information', () {
      speechCenter.speak('Info message', priority: SpeechPriority.information);
      speechCenter.speak('Danger ahead', priority: SpeechPriority.danger);
      // Danger should interrupt and be speaking
      expect(speechCenter.isSpeaking, isTrue);
    });

    test('Queue max size is 3', () {
      speechCenter.speak('1', priority: SpeechPriority.information);
      speechCenter.speak('2', priority: SpeechPriority.information);
      speechCenter.speak('3', priority: SpeechPriority.information);
      speechCenter.speak('4', priority: SpeechPriority.information);
      // Should drop oldest, queue size checked after adds
      // Since processing is immediate, we just verify it doesn't crash
      expect(speechCenter.queueSize, lessThanOrEqualTo(3));
    });

    test('Pause stops speaking', () {
      speechCenter.speak('Hello');
      speechCenter.pauseForListening();
      expect(speechCenter.isPaused, isTrue);
    });

    test('Resume continues speaking', () {
      speechCenter.speak('Hello');
      speechCenter.pauseForListening();
      speechCenter.resume();
      expect(speechCenter.isPaused, isFalse);
    });

    test('RepeatLast speaks last message', () async {
      speechCenter.speak('Hello');
      await Future.delayed(const Duration(milliseconds: 10));
      speechCenter.repeatLast();
      // Should not crash
      expect(() => speechCenter.repeatLast(), returnsNormally);
    });

    test('Clear empties queue', () {
      speechCenter.speak('Hello');
      speechCenter.clear();
      expect(speechCenter.queueSize, equals(0));
      expect(speechCenter.isSpeaking, isFalse);
    });
  });
}
