import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/voice/intent_matcher.dart';

void main() {
  group('IntentMatcher Tests', () {
    test('English: "take me to the library" matches startNavigation', () {
      final result = IntentMatcher.matchIntent('take me to the library', 'English');
      expect(result.intent, Intent.startNavigation);
      expect(result.place, 'the library');
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "where am i" matches whereAmI', () {
      final result = IntentMatcher.matchIntent('where am i', 'English');
      expect(result.intent, Intent.whereAmI);
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "go to washroom" matches startNavigation', () {
      final result = IntentMatcher.matchIntent('go to washroom', 'English');
      expect(result.intent, Intent.startNavigation);
      expect(result.place, 'washroom');
      expect(result.confidence, greaterThan(0.6));
    });

    test('Hindi: "मुझे लाइब्रेरी जाना है" matches startNavigation', () {
      final result = IntentMatcher.matchIntent('मुझे लाइब्रेरी जाना है', 'Hindi');
      // Pattern match: "मुझे जाना है" is in patterns, should match
      // Place extraction: "लाइब्रेरी" should be extracted
      expect(result.intent, Intent.startNavigation);
      expect(result.place, equals('लाइब्रेरी'));
      expect(result.confidence, greaterThan(0.6));
    });

    test('Hindi: "मैं कहाँ हूँ" matches whereAmI', () {
      final result = IntentMatcher.matchIntent('मैं कहाँ हूँ', 'Hindi');
      expect(result.intent, Intent.whereAmI);
      expect(result.confidence, greaterThan(0.6));
    });

    test('Hindi: "शौचालय ले चलो" matches startNavigation', () {
      final result = IntentMatcher.matchIntent('शौचालय ले चलो', 'Hindi');
      expect(result.intent, Intent.startNavigation);
      expect(result.place, isNotNull); // Place should be extracted
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "stop" matches stopNavigation', () {
      final result = IntentMatcher.matchIntent('stop', 'English');
      expect(result.intent, Intent.stopNavigation);
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "help" matches help', () {
      final result = IntentMatcher.matchIntent('help', 'English');
      expect(result.intent, Intent.help);
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "speak slower" matches slower', () {
      final result = IntentMatcher.matchIntent('speak slower', 'English');
      expect(result.intent, Intent.slower);
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "louder" matches louder', () {
      final result = IntentMatcher.matchIntent('louder', 'English');
      expect(result.intent, Intent.louder);
      expect(result.confidence, greaterThan(0.6));
    });

    test('English: "battery" matches battery', () {
      final result = IntentMatcher.matchIntent('battery', 'English');
      expect(result.intent, Intent.battery);
      expect(result.confidence, greaterThan(0.6));
    });

    test('Empty string returns unknown', () {
      final result = IntentMatcher.matchIntent('', 'English');
      expect(result.intent, Intent.unknown);
      expect(result.confidence, 0.0);
    });

    test('Unknown command returns unknown', () {
      final result = IntentMatcher.matchIntent('play music', 'English');
      expect(result.intent, Intent.unknown);
      expect(result.confidence, lessThan(0.6));
    });

    test('Negative: "take me to" with no place returns unknown', () {
      final result = IntentMatcher.matchIntent('take me to', 'English');
      expect(result.intent, Intent.unknown);
      expect(result.confidence, equals(0.0)); // No place extracted = 0.0 confidence
    });

    test('Negative: unknown place "somewhere" still matches pattern', () {
      final result = IntentMatcher.matchIntent('take me to somewhere', 'English');
      // Pattern "take me to" matches, and "somewhere" is extracted as place
      // This is correct behavior - we don't validate against known places at matching level
      expect(result.intent, Intent.startNavigation);
      expect(result.place, equals('somewhere'));
    });

    test('Negative: near-miss "liberry" still matches pattern', () {
      final result = IntentMatcher.matchIntent('go to liberry', 'English');
      // Pattern "go to" matches exactly, so confidence is high
      expect(result.intent, Intent.startNavigation);
      expect(result.place, equals('liberry'));
    });

    test('Negative: completely unrelated command returns unknown', () {
      final result = IntentMatcher.matchIntent('play some music', 'English');
      expect(result.intent, Intent.unknown);
      expect(result.confidence, lessThan(0.6));
    });

    test('Fuzzy matching: "librry" close to "library"', () {
      final result = IntentMatcher.matchIntent('go to librry', 'English');
      expect(result.intent, Intent.startNavigation);
      expect(result.place, 'librry');
      expect(result.confidence, greaterThan(0.6)); // Fuzzy match above threshold
    });

    test('Are similar: "library" and "library"', () {
      final similar = IntentMatcher.areSimilar('library', 'library'); // Same word
      expect(similar, true);
    });

    test('Are similar: "washroom" and "washrom" (typo)', () {
      final similar = IntentMatcher.areSimilar('washroom', 'washrom');
      expect(similar, true); // Should detect 1 char difference
    });

    test('Not similar: "washroom" and "kitchen"', () {
      final similar = IntentMatcher.areSimilar('washroom', 'kitchen');
      expect(similar, false);
    });
  });
}
