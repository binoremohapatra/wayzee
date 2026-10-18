import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/voice/voice_phrases.dart';

void main() {
  group('VoicePhrases Tests', () {
    setUp(() {
      VoicePhrases.resetRotation();
    });

    test('English: listening phrase rotation', () {
      final phrase1 = VoicePhrases.getPhrase('English', 'listening');
      final phrase2 = VoicePhrases.getPhrase('English', 'listening');
      final phrase3 = VoicePhrases.getPhrase('English', 'listening');
      
      expect(phrase1, isNotEmpty);
      expect(phrase2, isNotEmpty);
      expect(phrase3, isNotEmpty);
      expect(phrase1, isNot(equals(phrase2)));
      expect(phrase2, isNot(equals(phrase3)));
      // After 3 phrases, should cycle
    });

    test('Hindi: listening phrase rotation', () {
      final phrase1 = VoicePhrases.getPhrase('Hindi', 'listening');
      final phrase2 = VoicePhrases.getPhrase('Hindi', 'listening');
      
      expect(phrase1, isNotEmpty);
      expect(phrase2, isNotEmpty);
      expect(phrase1, isNot(equals(phrase2)));
    });

    test('Marathi: listening phrase rotation', () {
      final phrase1 = VoicePhrases.getPhrase('Marathi', 'listening');
      final phrase2 = VoicePhrases.getPhrase('Marathi', 'listening');
      
      expect(phrase1, isNotEmpty);
      expect(phrase2, isNotEmpty);
      expect(phrase1, isNot(equals(phrase2)));
    });

    test('Placeholder replacement', () {
      final phrase = VoicePhrases.getPhrase('English', 'success', placeholder: 'pharmacy');
      expect(phrase, contains('pharmacy'));
      expect(phrase, isNot(contains('library')));
    });

    test('Marathi fallback for unknown language', () {
      final phrase = VoicePhrases.getPhrase('Spanish', 'listening');
      expect(phrase, equals('I\'m listening.')); // Fallback to English
    });

    test('All languages have listening phrases', () {
      final english = VoicePhrases.getPhrase('English', 'listening');
      final hindi = VoicePhrases.getPhrase('Hindi', 'listening');
      final marathi = VoicePhrases.getPhrase('Marathi', 'listening');
      
      expect(english, isNotEmpty);
      expect(hindi, isNotEmpty);
      expect(marathi, isNotEmpty);
    });

    test('All languages have didNotCatch1 phrases', () {
      final english = VoicePhrases.getPhrase('English', 'didNotCatch1');
      final hindi = VoicePhrases.getPhrase('Hindi', 'didNotCatch1');
      final marathi = VoicePhrases.getPhrase('Marathi', 'didNotCatch1');
      
      expect(english, isNotEmpty);
      expect(hindi, isNotEmpty);
      expect(marathi, isNotEmpty);
    });

    test('All languages have success phrases', () {
      final english = VoicePhrases.getPhrase('English', 'success');
      final hindi = VoicePhrases.getPhrase('Hindi', 'success');
      final marathi = VoicePhrases.getPhrase('Marathi', 'success');
      
      expect(english, isNotEmpty);
      expect(hindi, isNotEmpty);
      expect(marathi, isNotEmpty);
    });

    test('Reset rotation works', () {
      final phrase1 = VoicePhrases.getPhrase('English', 'listening');
      VoicePhrases.resetRotation();
      final phrase2 = VoicePhrases.getPhrase('English', 'listening');
      
      expect(phrase1, equals(phrase2)); // Should restart from first
    });
  });
}
