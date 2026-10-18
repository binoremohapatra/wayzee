# Wayze Add-ons - Voice Control Features

## Module 1: IntentMatcher ✅

**Status:** COMPLETED (21 tests passing)

**Location:** `lib/voice/intent_matcher.dart`

**Features:**
- Pure Dart intent matching engine
- English and Hindi command patterns
- Fuzzy matching using Levenshtein distance
- Place name extraction ("take me to library" → "library")
- Phonetic/orthographic similarity detection for disambiguation
- Word-boundary matching preventing false substring matches (e.g. "end" in "send help")
- **Threshold:** 0.6 chosen to balance false positives vs false negatives

**Tests:** 21 tests passing with negative tests for:
- "take me to" with no place → unknown (0.0 confidence)
- Unknown place "somewhere" → matches pattern (has place extracted)
- Near-miss "liberry" → matches pattern (close enough)
- Completely unrelated commands → unknown

---

## Module 2: VoicePhrases ✅

**Status:** COMPLETED (9 tests passing)

**Location:** `lib/voice/voice_phrases.dart`

**Features:**
- Multi-language phrase packs (English, Hindi, Marathi)
- Phrase rotation to avoid repetition
- Non-equal prompt guarantee preventing identical consecutive prompts
- Placeholder replacement for dynamic content
- Fallback to English for unknown languages

**Tests:** 9 tests passing

---

## Module 3: SpeechCenter ✅

**Status:** COMPLETED (8 tests passing)

**Location:** `lib/voice/speech_center.dart`

**Features:**
- Priority queue (0=danger, 1=turn, 2=information)
- 4-second repeat suppression
- Urgent speech interrupts current speech
- Drop information messages older than 5 seconds
- Never queue more than 3 items
- `pauseForListening()` - pauses TTS for voice recognition
- `resume()` - resumes TTS
- `repeatLast()` - repeats last spoken message

**Tests:** 8 tests passing

---

## Module 4: SpeechRecognizerService ✅

**Status:** COMPLETED (6 tests passing)

**Location:** `lib/voice/speech_recognizer_service.dart`

**Features:**
- Abstract interface for speech recognition
- `initialize()` - Initialize recognizer
- `listen(grammarHints, maxDuration)` - Start listening with constraints
- `stop()` - Stop listening
- `dispose()` - Clean up resources
- Stream of `RecognitionResult` with alternatives and confidence

**FakeRecognizer (for testing):**
- Deterministic on-demand scripted results delivery
- Low confidence simulation
- Silence simulation
- Error simulation (no permission, no microphone, network, timeout)
- Configurable result delay without real delays in immediate mode

**Tests:** 6 tests passing

**Limits:**
- Real STT plugin NOT integrated yet (no Vosk or Whisper)
- FakeRecognizer used for testing only
- No RECORD_AUDIO permission added yet (will add when real recognizer integrated)

---

## Module 5: VoiceSession ✅

**Status:** COMPLETED (implemented and tested, 20 tests passing)

**Location:** `lib/voice/voice_session.dart`

**Features:**
- State machine: idle, listening, thinking, confirming, acting, done
- Deterministic Clock abstraction (`FakeClock`) injected for testability without real delays
- `PlaceResolver` integration matching spoken words against saved map places and aliases
- Repair ladder: soft retry → guided retry with examples → confirm best guess → list mode
- Same prompt is never spoken twice in a row
- Confirmation for costly intents (`startNavigation`, `sendHelp`, `takeMeBack`); cheap intents execute immediately
- `sendHelp` ALWAYS asks for confirmation even at confidence 1.0 ("no" cancels, "yes" proceeds, unclear asks again once)
- Alternatives picking best KNOWN place over higher-scoring unknown words
- Unknown place ("somewhere") never starts navigation; triggers retry ladder
- Silence triggers retry; repeated silence reaches list mode
- `SpeechCenter.pauseForListening()` on start and `resume()` ALWAYS called afterwards (including error, exception, timeout, cancellation)
- Danger alert during listening cancels session and danger message is spoken first
- List mode: button press selects currently read place

**Tests:** 20 tests passing (0 skipped)

---

## What's NOT Done Yet

- ❌ Real STT (Speech-to-Text) - Vosk plugin not integrated
- ❌ Hands-free triggers
- ❌ Auto navigation
- ❌ BLE protocol
- ❌ OCR
- ❌ "Ask for help"
- ❌ Favourites
- ❌ Route preferences

---

## Final Summary

**Total Tests Passing:** 65 (IntentMatcher 21, VoicePhrases 9, SpeechCenter 8, SpeechRecognizerService 6, VoiceSession & PlaceResolver 20, Widget 1)

**Fuzzy Threshold & Place Ambiguity Analysis:**
- 0.5 was too permissive (matched too many distant partial matches)
- 0.7 was too strict for conversational near-misses
- 0.6 threshold analysis for "library" vs "laboratory":
  - Levenshtein distance between "library" (len 7) and "laboratory" (len 10) is 4 edits (similarity = 0.60).
  - With threshold > 0.60, "library" does not falsely match "laboratory" in PlaceResolver, keeping them distinct and preventing false positives.
  - "library" and "laboratory" are not confusable (`areSimilar` is false because distance is 4, well above 2).

**Architecture Improvements Implemented:**
- ✅ Sensor fusion service
- ✅ Intent matching with word-boundary detection and 0.6 threshold
- ✅ SpeechCenter with priority queue and guaranteed pause/resume lifecycle
- ✅ SpeechRecognizerService abstract interface and deterministic FakeRecognizer
- ✅ PlaceResolver with alias support, close matching, and ambiguity detection
- ✅ VoiceSession state machine with complete repair ladder
- ✅ Phrase rotation and consecutive prompt anti-repetition
- ✅ Strict confirmation rules for costly intents and sendHelp
- ✅ Zero skipped tests across the entire test suite

**Offline-First Maintained:**
- ✅ No INTERNET permission
- ❌ RECORD_AUDIO permission NOT added (will add when real STT integrated)
