import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/data/tts_stt/tts_service.dart';
import 'package:wayze/domain/models/alert_item.dart';

void main() {
  group('MockTtsService Contract and Interruption Tests', () {
    late MockTtsService tts;

    setUp(() {
      tts = MockTtsService();
    });

    tearDown(() {
      tts.dispose();
    });

    test('initialize updates isInitialized state', () async {
      expect(tts.isInitialized, isFalse);
      await tts.initialize(language: 'en-US', speechRate: 0.5);
      expect(tts.isInitialized, isTrue);
    });

    test('speak updates state and records utterance', () async {
      expect(tts.isSpeaking, isFalse);
      await tts.speak('Stairs ahead', priority: AlertPriority.p1Navigation);

      expect(tts.isSpeaking, isTrue);
      expect(tts.spokenUtterances, contains('Stairs ahead'));
      expect(tts.spokenPriorities, contains(AlertPriority.p1Navigation));

      tts.simulateCompletion();
      expect(tts.isSpeaking, isFalse);
    });

    test('p0Danger utterance immediately interrupts ongoing lower priority speech', () async {
      await tts.speak('Turn slight left in five meters', priority: AlertPriority.p1Navigation);
      expect(tts.isSpeaking, isTrue);
      expect(tts.interruptCount, equals(0));

      // P0 Danger arrives while speaking
      await tts.speak('Drop-off detected! Stop!', priority: AlertPriority.p0Danger);

      expect(tts.interruptCount, equals(1));
      expect(tts.spokenUtterances.length, equals(2));
      expect(tts.spokenUtterances.last, equals('Drop-off detected! Stop!'));
      expect(tts.spokenPriorities.last, equals(AlertPriority.p0Danger));
      expect(tts.isSpeaking, isTrue);
    });

    test('interrupt method resets isSpeaking and increments count', () async {
      await tts.speak('General information notice', priority: AlertPriority.p2Info);
      expect(tts.isSpeaking, isTrue);

      await tts.interrupt();
      expect(tts.isSpeaking, isFalse);
      expect(tts.interruptCount, equals(1));
    });

    test('speakingStateStream emits true on start and false on completion/interrupt', () async {
      final states = <bool>[];
      final subscription = tts.speakingStateStream.listen(states.add);

      await tts.speak('Warning message', priority: AlertPriority.p1Navigation);
      tts.simulateCompletion();
      await tts.speak('Danger alert', priority: AlertPriority.p0Danger);
      await tts.interrupt();

      // Allow microtasks to propagate stream events
      await Future<void>.delayed(Duration.zero);

      expect(states, [true, false, true, false]);
      await subscription.cancel();
    });

    test('clear resets history and counts', () async {
      await tts.speak('Step one', priority: AlertPriority.p1Navigation);
      await tts.interrupt();
      expect(tts.spokenUtterances.isNotEmpty, isTrue);
      expect(tts.interruptCount, equals(1));

      tts.clear();
      expect(tts.spokenUtterances, isEmpty);
      expect(tts.spokenPriorities, isEmpty);
      expect(tts.interruptCount, equals(0));
      expect(tts.isSpeaking, isFalse);
    });
  });
}
