import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/voice/speech_center.dart';
import 'package:wayze/voice/speech_recognizer_service.dart';
import 'package:wayze/voice/voice_session.dart';
import 'package:wayze/voice/intent_matcher.dart';
import 'package:wayze/voice/voice_phrases.dart';
import 'package:wayze/voice/clock.dart';
import 'package:wayze/voice/place_resolver.dart';

void main() {
  group('VoiceSession Tests', () {
    late SpeechCenter speechCenter;
    late FakeRecognizer recognizer;
    late FakeClock clock;
    late VoiceSession session;

    setUp(() {
      speechCenter = SpeechCenter();
      VoicePhrases.resetRotation();
    });

    tearDown(() async {
      await session.stop();
      await recognizer.dispose();
      speechCenter.clear();
    });

    test('Session starts in idle state and transitions to listening on start', () async {
      recognizer = FakeRecognizer(immediate: true);
      clock = FakeClock();
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
      );
      expect(session.state, VoiceSessionState.idle);

      await session.start();
      expect(session.state, VoiceSessionState.listening);
    });

    test('Repair ladder order: soft retry -> guided retry with examples -> confirm best guess -> list mode', () async {
      // 1: soft retry (unrecognized)
      // 2: guided retry with examples (unrecognized)
      // 3: confirm guess (has alternative "library")
      // 4: rejected guess leads to list mode
      final results = [
        RecognitionResult(
          text: 'garbled one',
          alternatives: [],
          confidence: 0.2,
          isFinal: true,
        ),
        RecognitionResult(
          text: 'garbled two',
          alternatives: [],
          confidence: 0.2,
          isFinal: true,
        ),
        RecognitionResult(
          text: 'libry',
          alternatives: ['libry'],
          confidence: 0.3,
          isFinal: true,
        ),
      ];

      recognizer = FakeRecognizer(
        scriptedResults: results,
        immediate: true,
      );
      clock = FakeClock();

      bool listModeReached = false;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onListModeSelected: () {
          listModeReached = true;
        },
      );

      await session.start();
      await pumpEventQueue();

      // Attempt 1: soft retry
      expect(session.retryState, equals(RetryState.softRetry));
      expect(session.retryCount, equals(1));

      // Advance to trigger retry 2
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // Attempt 2: guided retry with examples
      expect(session.retryState, equals(RetryState.guidedRetry));
      expect(session.retryCount, equals(2));

      // Advance to trigger retry 3
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // Attempt 3: best guess "library" from alternatives
      expect(session.retryState, equals(RetryState.confirmGuess));
      expect(session.state, equals(VoiceSessionState.confirming));

      // User says "no" to confirmation -> reaches list mode
      session.handleNo();
      expect(listModeReached, isTrue);
      expect(session.retryState, equals(RetryState.listMode));
    });

    test('The same prompt is never spoken twice in a row', () async {
      final results = [
        RecognitionResult(
          text: 'unrecognized one',
          alternatives: [],
          confidence: 0.2,
          isFinal: true,
        ),
        RecognitionResult(
          text: 'unrecognized two',
          alternatives: [],
          confidence: 0.2,
          isFinal: true,
        ),
      ];
      recognizer = FakeRecognizer(
        scriptedResults: results,
        immediate: true,
      );
      clock = FakeClock();

      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
      );

      await session.start();
      await pumpEventQueue();
      final prompt1 = session.lastPrompt;

      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      final prompt2 = session.lastPrompt;

      expect(prompt1, isNotNull);
      expect(prompt2, isNotNull);
      expect(prompt1, isNot(equals(prompt2)));
    });

    test('Silence leads to a retry; repeated silence reaches list mode', () async {
      recognizer = FakeRecognizer(
        simulateSilence: true,
        immediate: true,
      );
      clock = FakeClock();

      bool listModeReached = false;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onListModeSelected: () {
          listModeReached = true;
        },
      );

      await session.start();
      await pumpEventQueue();

      // 1st silence -> soft retry
      expect(session.retryState, equals(RetryState.softRetry));
      expect(session.retryCount, equals(1));

      // 2nd silence -> guided retry
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      expect(session.retryState, equals(RetryState.guidedRetry));
      expect(session.retryCount, equals(2));

      // 3rd silence -> reaches list mode because there is no best guess
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      expect(listModeReached, isTrue);
      expect(session.retryState, equals(RetryState.listMode));
    });

    test('sendHelp ALWAYS asks for confirmation, even with confidence 1.0; "yes" proceeds', () async {
      recognizer = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'send help',
            alternatives: ['emergency'],
            confidence: 1.0,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      clock = FakeClock();

      Intent? matchedIntent;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onIntentMatched: (intent, place) {
          matchedIntent = intent;
        },
      );

      await session.start();
      await pumpEventQueue();

      // Must be in confirming state despite 1.0 confidence
      expect(session.state, equals(VoiceSessionState.confirming));
      expect(matchedIntent, isNull);

      // "yes" proceeds
      session.handleYes();
      expect(matchedIntent, equals(Intent.sendHelp));
      expect(session.state, equals(VoiceSessionState.done));
    });

    test('sendHelp confirmation: "no" cancels', () async {
      recognizer = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'send help',
            alternatives: [],
            confidence: 1.0,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      clock = FakeClock();

      Intent? matchedIntent;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onIntentMatched: (intent, place) {
          matchedIntent = intent;
        },
      );

      await session.start();
      await pumpEventQueue();
      expect(session.state, equals(VoiceSessionState.confirming));

      // "no" cancels
      session.handleNo();
      expect(matchedIntent, isNull);
      expect(session.state, equals(VoiceSessionState.idle));
    });

    test('sendHelp confirmation: unclear answer asks again once, then cancels on second unclear', () async {
      recognizer = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'send help',
            alternatives: [],
            confidence: 1.0,
            isFinal: true,
          ),
          // 1st unclear voice response
          RecognitionResult(
            text: 'what did you say',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
          // 2nd unclear voice response
          RecognitionResult(
            text: 'mumble mumble',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      clock = FakeClock();

      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
      );

      await session.start();
      await pumpEventQueue();
      expect(session.state, equals(VoiceSessionState.confirming));

      // Advance clock to trigger 1st unclear response
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // Asks again once, still confirming
      expect(session.state, equals(VoiceSessionState.confirming));

      // Advance clock to trigger 2nd unclear response
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // Second unclear cancels confirmation
      expect(session.state, equals(VoiceSessionState.idle));
    });

    test('startNavigation and takeMeBack confirm; cheap intents do not', () async {
      // 1. startNavigation confirms
      var rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'take me to library',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      var sess = VoiceSession(
        speechCenter: speechCenter,
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library'],
        clock: FakeClock(),
      );
      await sess.start();
      await pumpEventQueue();
      expect(sess.state, equals(VoiceSessionState.confirming));
      await sess.stop();

      // 2. takeMeBack confirms
      rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'take me back',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      sess = VoiceSession(
        speechCenter: speechCenter,
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library'],
        clock: FakeClock(),
      );
      await sess.start();
      await pumpEventQueue();
      expect(sess.state, equals(VoiceSessionState.confirming));
      await sess.stop();

      // 3. repeat does NOT confirm (executes immediately)
      Intent? matched;
      rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'repeat',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      sess = VoiceSession(
        speechCenter: speechCenter,
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library'],
        clock: FakeClock(),
        onIntentMatched: (i, p) => matched = i,
      );
      await sess.start();
      await pumpEventQueue();
      expect(matched, equals(Intent.repeat));
      expect(sess.state, equals(VoiceSessionState.done));
      await sess.stop();

      // 4. louder does NOT confirm (executes immediately)
      rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'louder',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      sess = VoiceSession(
        speechCenter: speechCenter,
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library'],
        clock: FakeClock(),
        onIntentMatched: (i, p) => matched = i,
      );
      await sess.start();
      await pumpEventQueue();
      expect(matched, equals(Intent.louder));
      expect(sess.state, equals(VoiceSessionState.done));
      await sess.stop();

      // 5. slower does NOT confirm (executes immediately)
      rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'speak slower',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      sess = VoiceSession(
        speechCenter: speechCenter,
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library'],
        clock: FakeClock(),
        onIntentMatched: (i, p) => matched = i,
      );
      await sess.start();
      await pumpEventQueue();
      expect(matched, equals(Intent.slower));
      expect(sess.state, equals(VoiceSessionState.done));
      await sess.stop();
    });

    test('Alternatives: best KNOWN place among alternatives is chosen over higher-scoring unknown word', () async {
      // Primary text: "take me to somewhere" (0.95 confidence, but "somewhere" is unknown)
      // Alternative: "take me to library" (0.85 confidence, "library" is a known place)
      recognizer = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'take me to somewhere',
            alternatives: ['take me to library'],
            confidence: 0.95,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      clock = FakeClock();

      String? confirmedPlace;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onIntentMatched: (intent, place) {
          confirmedPlace = place;
        },
      );

      await session.start();
      await pumpEventQueue();

      // Should be confirming library, not somewhere
      expect(session.state, equals(VoiceSessionState.confirming));
      session.handleYes();
      expect(confirmedPlace, equals('library'));
    });

    test('SpeechCenter.pauseForListening is called when listening starts, and resume is ALWAYS called afterwards', () async {
      recognizer = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'where am i',
            alternatives: [],
            confidence: 0.9,
            isFinal: true,
          ),
        ],
        immediate: false, // will delay slightly so we inspect pause
        resultDelay: const Duration(milliseconds: 50),
      );
      clock = FakeClock();
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library'],
        clock: clock,
      );

      await session.start();
      expect(speechCenter.isPaused, isTrue); // Paused when listening starts

      await Future.delayed(const Duration(milliseconds: 100));
      expect(speechCenter.isPaused, isFalse); // Resumed after result delivered
    });

    test('SpeechCenter.resume is called when recognizer throws an error', () async {
      recognizer = FakeRecognizer(
        simulateError: true,
        errorType: RecognitionError.noPermission,
        immediate: true,
      );
      clock = FakeClock();
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library'],
        clock: clock,
      );

      await session.start();
      await pumpEventQueue();
      expect(speechCenter.isPaused, isFalse); // Resume must be called on error
      expect(session.state, equals(VoiceSessionState.done));
    });

    test('SpeechCenter.resume is called on silence/timeout', () async {
      recognizer = FakeRecognizer(
        simulateSilence: true,
        immediate: true,
      );
      clock = FakeClock();
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library'],
        clock: clock,
      );

      await session.start();
      await pumpEventQueue();
      expect(speechCenter.isPaused, isFalse); // Resume must be called on silence/timeout
    });

    test('Danger alert during listening cancels session and danger message is spoken first', () async {
      recognizer = FakeRecognizer(immediate: false); // keeps listening
      clock = FakeClock();
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library'],
        clock: clock,
      );

      await session.start();
      expect(session.state, equals(VoiceSessionState.listening));

      session.handleDangerAlert('Watch out! Step down ahead');

      expect(session.state, equals(VoiceSessionState.idle));
      expect(speechCenter.isPaused, isFalse);
      expect(speechCenter.isSpeaking, isTrue); // Danger speech prioritized immediately
    });

    test('List mode: button press selects the currently read place', () async {
      recognizer = FakeRecognizer(
        simulateSilence: true,
        immediate: true,
      );
      clock = FakeClock();

      String? selectedPlace;
      session = VoiceSession(
        speechCenter: speechCenter,
        recognizer: recognizer,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: clock,
        onIntentMatched: (intent, place) {
          selectedPlace = place;
        },
      );

      await session.start();
      await pumpEventQueue();
      // 1st silence -> retry 1
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // 2nd silence -> retry 2
      clock.advance(const Duration(milliseconds: 600));
      await pumpEventQueue();
      // 3rd silence -> list mode
      expect(session.retryState, equals(RetryState.listMode));
      expect(session.currentListPlace, equals('library'));

      // Press button to select currently read place
      session.onButtonPress();

      expect(selectedPlace, equals('library'));
      expect(session.state, equals(VoiceSessionState.done));
    });
  });

  group('PlaceResolver Tests', () {
    test('Exact match returns exactMatch', () {
      final resolver = PlaceResolver(
        knownPlaces: ['library', 'washroom'],
      );
      final result = resolver.resolve('library');
      expect(result.result, equals(PlaceMatchResult.exactMatch));
      expect(result.place, equals('library'));
    });

    test('Close match: "liberry" matches library', () {
      final resolver = PlaceResolver(
        knownPlaces: ['library', 'washroom'],
      );
      final result = resolver.resolve('liberry');
      expect(result.result, equals(PlaceMatchResult.closeMatch));
      expect(result.place, equals('library'));
    });

    test('Ambiguous match: "libarty" matches both library and liberty', () {
      final resolver = PlaceResolver(
        knownPlaces: ['library', 'liberty'],
      );
      final result = resolver.resolve('libarty');
      expect(result.result, equals(PlaceMatchResult.ambiguous));
      expect(result.alternatives, contains('library'));
      expect(result.alternatives, contains('liberty'));
    });

    test('No match: "somewhere" returns notFound and never starts navigation', () async {
      final resolver = PlaceResolver(
        knownPlaces: ['library', 'washroom'],
      );
      final result = resolver.resolve('somewhere');
      expect(result.result, equals(PlaceMatchResult.notFound));
      expect(result.place, isNull);

      // Verify that VoiceSession with PlaceResolver never starts navigation on "somewhere"
      final rec = FakeRecognizer(
        scriptedResults: [
          RecognitionResult(
            text: 'take me to somewhere',
            alternatives: [],
            confidence: 0.95,
            isFinal: true,
          ),
        ],
        immediate: true,
      );
      bool navigationStarted = false;
      final sess = VoiceSession(
        speechCenter: SpeechCenter(),
        recognizer: rec,
        language: 'English',
        availablePlaces: ['library', 'washroom'],
        clock: FakeClock(),
        onIntentMatched: (intent, place) {
          if (intent == Intent.startNavigation) {
            navigationStarted = true;
          }
        },
      );

      await sess.start();
      await pumpEventQueue();
      // Should reject unknown place and trigger retry ladder instead
      expect(navigationStarted, isFalse);
      expect(sess.retryState, equals(RetryState.softRetry));
      await sess.stop();
    });

    test('Alias works: "pharmacy" aliases to "medical"', () {
      final resolver = PlaceResolver(
        knownPlaces: ['medical'],
        aliases: {'medical': ['pharmacy', 'drugstore']},
      );
      final result = resolver.resolve('pharmacy');
      expect(result.result, equals(PlaceMatchResult.exactMatch));
      expect(result.place, equals('medical'));
    });
  });

  group('Requirement 4: Proof and Analysis for "library" vs "laboratory"', () {
    test('Shows exact Levenshtein distance and similarity for library vs laboratory', () {
      // "library" (len 7) vs "laboratory" (len 10)
      // Distance is 4 edits (i->a, insert o, insert t, insert o):
      // l-i-b-r-a-r-y -> l-a-b-o-r-a-t-o-r-y
      // Max length = 10
      // Similarity = 1.0 - (4 / 10) = 0.60
      final similarUnderAreSimilar = IntentMatcher.areSimilar('library', 'laboratory');
      // areSimilar requires distance < 2, so distance 4 is NOT considered similar
      expect(similarUnderAreSimilar, isFalse);

      // In PlaceResolver:
      // Spoken word "library" against known place "laboratory":
      // Since similarity is 0.60 (not >= 0.70) and distance is 4 (not <= 2),
      // "library" is NOT confused with "laboratory" and returns notFound.
      final resolver = PlaceResolver(knownPlaces: ['laboratory']);
      final result = resolver.resolve('library');
      expect(result.result, equals(PlaceMatchResult.notFound));

      // Both words independently match startNavigation when used with "go to"
      final libMatch = IntentMatcher.matchIntent('go to library', 'English');
      final labMatch = IntentMatcher.matchIntent('go to laboratory', 'English');
      expect(libMatch.intent, equals(Intent.startNavigation));
      expect(libMatch.place, equals('library'));
      expect(labMatch.intent, equals(Intent.startNavigation));
      expect(labMatch.place, equals('laboratory'));
    });
  });
}
