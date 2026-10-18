import 'dart:async';
import 'speech_center.dart';
import 'speech_recognizer_service.dart';
import 'intent_matcher.dart';
import 'voice_phrases.dart';
import 'clock.dart';
import 'place_resolver.dart';

enum VoiceSessionState {
  idle,
  listening,
  thinking,
  confirming,
  acting,
  done,
}

enum RetryState {
  none,
  softRetry,
  guidedRetry,
  confirmGuess,
  listMode,
}

class VoiceSession {
  final SpeechCenter _speechCenter;
  final SpeechRecognizerService _recognizer;
  final String _language;
  final List<String> _availablePlaces;
  final PlaceResolver _placeResolver;
  final Clock _clock;

  VoiceSessionState _state = VoiceSessionState.idle;
  RetryState _retryState = RetryState.none;
  String? _lastPrompt;
  int _retryCount = 0;
  int _unclearConfirmationCount = 0;
  int _currentListIndex = 0;
  StreamSubscription? _recognitionSubscription;
  String? _pendingPlace;
  Intent? _pendingIntent;
  Timer? _scheduledTimer;

  // Callbacks
  final void Function(Intent intent, String? place)? onIntentMatched;
  final void Function()? onListModeSelected;

  VoiceSession({
    required SpeechCenter speechCenter,
    required SpeechRecognizerService recognizer,
    required String language,
    required List<String> availablePlaces,
    Map<String, List<String>>? aliases,
    PlaceResolver? placeResolver,
    Clock? clock,
    this.onIntentMatched,
    this.onListModeSelected,
  })  : _speechCenter = speechCenter,
        _recognizer = recognizer,
        _language = language,
        _availablePlaces = availablePlaces,
        _placeResolver = placeResolver ??
            PlaceResolver(
              knownPlaces: availablePlaces,
              aliases: aliases,
            ),
        _clock = clock ?? RealClock();

  // Start voice session
  Future<void> start() async {
    if (_state != VoiceSessionState.idle) return;

    _state = VoiceSessionState.listening;
    _retryState = RetryState.none;
    _retryCount = 0;
    _unclearConfirmationCount = 0;
    _currentListIndex = 0;
    _lastPrompt = null;
    _pendingIntent = null;
    _pendingPlace = null;

    // Pause TTS for listening
    _speechCenter.pauseForListening();

    // Speak listening phrase
    _speakPrompt('listening');

    // Start recognition
    _startRecognition();
  }

  // Stop voice session
  Future<void> stop() async {
    if (_state == VoiceSessionState.idle) return;

    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    await _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    await _recognizer.stop();

    _speechCenter.resume();
    _state = VoiceSessionState.idle;
  }

  bool _resultReceivedInCurrentTurn = false;

  // Start recognition with pause/resume guarantee
  void _startRecognition() {
    _resultReceivedInCurrentTurn = false;
    _speechCenter.pauseForListening();
    try {
      _recognitionSubscription?.cancel();
      _recognitionSubscription = _recognizer
          .listen(
            grammarHints: _buildGrammarHints(),
            maxDuration: const Duration(seconds: 6),
          )
          .listen(
            _onRecognitionResult,
            onError: _onRecognitionError,
            onDone: _onRecognitionDone,
          );
    } catch (e) {
      _onRecognitionError(e);
    }
  }

  // Build grammar hints from available places
  List<String> _buildGrammarHints() {
    final hints = <String>[];
    hints.addAll(['take me to', 'go to', 'where am i', 'stop', 'help', 'repeat', 'yes', 'no']);
    hints.addAll(_availablePlaces);
    return hints;
  }

  // Handle recognition result
  void _onRecognitionResult(RecognitionResult result) {
    _resultReceivedInCurrentTurn = true;
    // Resume TTS after listening ends
    _speechCenter.resume();

    // If awaiting confirmation, process yes/no voice response
    if (_state == VoiceSessionState.confirming) {
      _handleConfirmationResponse(result);
      return;
    }

    if (_state != VoiceSessionState.listening) return;

    _state = VoiceSessionState.thinking;

    // Pick best match considering alternatives and known places
    final bestCandidate = _resolveBestCandidate(result);

    if (bestCandidate == null ||
        bestCandidate.intent == Intent.unknown ||
        bestCandidate.confidence < 0.6) {
      _handleLowConfidence(result);
      return;
    }

    // Check if place is known for navigation intent
    if (bestCandidate.intent == Intent.startNavigation) {
      final place = bestCandidate.place;
      if (place == null || place.isEmpty) {
        _handleLowConfidence(result);
        return;
      }
      final resolution = _placeResolver.resolve(place);
      if (resolution.result == PlaceMatchResult.notFound) {
        // Unknown place: never start navigation
        _handleLowConfidence(result);
        return;
      }
    }

    // Check if confirmation needed
    if (_requiresConfirmation(bestCandidate.intent)) {
      _confirmIntent(bestCandidate);
      return;
    }

    // Execute intent immediately for cheap intents
    _executeIntent(bestCandidate);
  }

  // Resolves the best candidate between primary text and alternatives:
  // "The best KNOWN place among alternatives is chosen over a higher-scoring unknown word."
  IntentMatch? _resolveBestCandidate(RecognitionResult result) {
    final candidates = <String>[result.text, ...result.alternatives];
    IntentMatch? bestKnownPlaceMatch;
    IntentMatch? primaryMatch;

    for (int i = 0; i < candidates.length; i++) {
      final text = candidates[i].trim();
      if (text.isEmpty) continue;

      final match = IntentMatcher.matchIntent(text, _language);
      if (match.intent == Intent.unknown) continue;

      if (i == 0) {
        primaryMatch = match;
      }

      if (match.intent == Intent.startNavigation && match.place != null) {
        final resolution = _placeResolver.resolve(match.place!);
        if (resolution.result == PlaceMatchResult.exactMatch ||
            resolution.result == PlaceMatchResult.closeMatch) {
          final resolvedMatch = IntentMatch(
            intent: match.intent,
            place: resolution.place ?? match.place,
            confidence: match.confidence,
          );

          if (bestKnownPlaceMatch == null ||
              resolvedMatch.confidence > bestKnownPlaceMatch.confidence ||
              resolution.result == PlaceMatchResult.exactMatch) {
            bestKnownPlaceMatch = resolvedMatch;
          }
        }
      }
    }

    // If an alternative had a KNOWN place, prioritize it
    if (bestKnownPlaceMatch != null) {
      if (primaryMatch != null && primaryMatch.intent == Intent.startNavigation && primaryMatch.place != null) {
        final primResolution = _placeResolver.resolve(primaryMatch.place!);
        if (primResolution.result == PlaceMatchResult.notFound) {
          return bestKnownPlaceMatch;
        }
      } else if (primaryMatch == null || primaryMatch.intent != Intent.startNavigation) {
        return bestKnownPlaceMatch;
      }
      return bestKnownPlaceMatch;
    }

    return primaryMatch;
  }

  // Handle low confidence result or failed match
  void _handleLowConfidence(RecognitionResult result) {
    _retryCount++;

    if (_retryCount == 1) {
      // Soft retry
      _retryState = RetryState.softRetry;
      _speakPrompt('didNotCatch1');
      _scheduleListeningRetry();
    } else if (_retryCount == 2) {
      // Guided retry with examples
      _retryState = RetryState.guidedRetry;
      _speakPrompt('didNotCatch2');
      _scheduleListeningRetry();
    } else if (_retryCount == 3) {
      // Try to confirm best guess if there is one
      final bestGuess = _findBestGuess(result);
      if (bestGuess != null) {
        _retryState = RetryState.confirmGuess;
        _confirmGuess(bestGuess);
      } else {
        // Switch to list mode
        _enterListMode();
      }
    } else {
      // Switch to list mode
      _enterListMode();
    }
  }

  // Find best guess from alternatives matching a known place
  String? _findBestGuess(RecognitionResult result) {
    for (final alt in result.alternatives) {
      final match = IntentMatcher.matchIntent(alt, _language);
      final place = match.place ?? alt;
      final resolution = _placeResolver.resolve(place);
      if (resolution.result == PlaceMatchResult.exactMatch ||
          resolution.result == PlaceMatchResult.closeMatch) {
        return resolution.place ?? place;
      }
    }
    return null;
  }

  // Confirm intent
  void _confirmIntent(IntentMatch match) {
    _state = VoiceSessionState.confirming;
    _pendingIntent = match.intent;
    _pendingPlace = match.place;
    _unclearConfirmationCount = 0;

    if (match.intent == Intent.sendHelp) {
      _speakPrompt('confirmHelp');
    } else {
      _speakPrompt('confirmGuess', placeholder: match.place ?? 'destination');
    }

    _scheduleListeningForConfirmation();
  }

  // Confirm guess
  void _confirmGuess(String guess) {
    _state = VoiceSessionState.confirming;
    _pendingIntent = Intent.startNavigation;
    _pendingPlace = guess;
    _unclearConfirmationCount = 0;

    _speakPrompt('confirmGuess', placeholder: guess);
    _scheduleListeningForConfirmation();
  }

  // Handle voice response during confirmation state
  void _handleConfirmationResponse(RecognitionResult result) {
    final text = result.text.toLowerCase().trim();

    if (_isAffirmative(text)) {
      handleYes();
      return;
    }

    if (_isNegative(text)) {
      handleNo();
      return;
    }

    // Unclear answer
    _unclearConfirmationCount++;
    if (_unclearConfirmationCount == 1) {
      // Unclear answer asks again once
      _speakPrompt('confirmYesNo');
      _scheduleListeningForConfirmation();
    } else {
      // Repeated unclear cancels confirmation
      _cancelConfirmation();
    }
  }

  bool _isAffirmative(String text) {
    const affirmatives = ['yes', 'yeah', 'yep', 'sure', 'confirm', 'proceed', 'correct', 'हाँ', 'हाँ जी', 'हो', 'होय'];
    return affirmatives.any((a) => text.contains(a));
  }

  bool _isNegative(String text) {
    const negatives = ['no', 'nope', 'cancel', 'don\'t', 'stop', 'नहीं', 'ना', 'नाही', 'नको'];
    return negatives.any((n) => text.contains(n));
  }

  // Handle yes response
  void handleYes() {
    if (_state != VoiceSessionState.confirming) return;

    final intent = _pendingIntent ?? Intent.startNavigation;
    final place = _pendingPlace;

    _scheduledTimer?.cancel();
    _executeIntent(IntentMatch(
      intent: intent,
      place: place,
      confidence: 1.0,
    ));
  }

  // Handle no response
  void handleNo() {
    if (_state != VoiceSessionState.confirming) return;

    if (_retryState == RetryState.confirmGuess) {
      _enterListMode();
      return;
    }

    _cancelConfirmation();
  }

  void _cancelConfirmation() {
    _pendingIntent = null;
    _pendingPlace = null;
    _scheduledTimer?.cancel();
    _state = VoiceSessionState.idle;
    _retryState = RetryState.none;
    _speechCenter.resume();
  }

  // Execute intent
  void _executeIntent(IntentMatch match) {
    _scheduledTimer?.cancel();
    _state = VoiceSessionState.acting;

    // Speak success phrase
    _speakPrompt('success', placeholder: match.place ?? 'destination');

    // Callback
    onIntentMatched?.call(match.intent, match.place);

    _state = VoiceSessionState.done;
    _scheduleIdle();
  }

  // Enter list mode
  void _enterListMode() {
    _scheduledTimer?.cancel();
    _state = VoiceSessionState.confirming;
    _retryState = RetryState.listMode;
    _currentListIndex = 0;

    _speakPrompt('switchToList');

    onListModeSelected?.call();

    // Read current list place if available
    if (_availablePlaces.isNotEmpty) {
      _speechCenter.speak(currentListPlace!, priority: SpeechPriority.turn);
    }
  }

  // Currently read place in list mode
  String? get currentListPlace =>
      _availablePlaces.isNotEmpty ? _availablePlaces[_currentListIndex % _availablePlaces.length] : null;

  void nextListPlace() {
    if (_availablePlaces.isNotEmpty) {
      _currentListIndex = (_currentListIndex + 1) % _availablePlaces.length;
      final place = currentListPlace!;
      _speechCenter.speak(place, priority: SpeechPriority.turn);
    }
  }

  // List mode: button press selects the currently read place
  void onButtonPress() {
    if (_retryState == RetryState.listMode && currentListPlace != null) {
      final selected = currentListPlace!;
      _executeIntent(IntentMatch(
        intent: Intent.startNavigation,
        place: selected,
        confidence: 1.0,
      ));
    }
  }

  // Schedule retry listening
  void _scheduleListeningRetry() {
    _scheduledTimer?.cancel();
    _scheduledTimer = _clock.schedule(const Duration(milliseconds: 500), () {
      if (_state == VoiceSessionState.idle) return;
      _state = VoiceSessionState.listening;
      _startRecognition();
    });
  }

  // Schedule listening for confirmation
  void _scheduleListeningForConfirmation() {
    _scheduledTimer?.cancel();
    _scheduledTimer = _clock.schedule(const Duration(milliseconds: 500), () {
      if (_state == VoiceSessionState.idle) return;
      _startRecognition();
    });
  }

  // Schedule idle transition
  void _scheduleIdle() {
    _scheduledTimer?.cancel();
    _scheduledTimer = _clock.schedule(const Duration(seconds: 2), () {
      _state = VoiceSessionState.idle;
    });
  }

  // Speak prompt, ensuring the same prompt is never spoken twice in a row
  void _speakPrompt(String key, {String? placeholder}) {
    var phrase = VoicePhrases.getPhrase(
      _language,
      key,
      placeholder: placeholder,
      notEqual: _lastPrompt,
    );

    // Guarantee that the prompt is never identical to the immediately preceding prompt
    if (phrase == _lastPrompt) {
      phrase = 'Please note: $phrase';
    }

    _speechCenter.speak(phrase, priority: SpeechPriority.turn);
    _lastPrompt = phrase;
  }

  // Check if intent requires confirmation
  // startNavigation, takeMeBack, sendHelp require confirmation; cheap intents do not
  bool _requiresConfirmation(Intent intent) {
    return intent == Intent.startNavigation ||
        intent == Intent.sendHelp ||
        intent == Intent.takeMeBack;
  }

  // Handle recognition error: resume is always called
  void _onRecognitionError(Object error) {
    _scheduledTimer?.cancel();
    _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    _state = VoiceSessionState.done;
    _speechCenter.resume();
    _speechCenter.speak('Recognition error', priority: SpeechPriority.danger);
    _scheduleIdle();
  }

  // Handle recognition done / silence
  void _onRecognitionDone() {
    _speechCenter.resume();
    if (_resultReceivedInCurrentTurn) {
      return;
    }
    if (_state == VoiceSessionState.listening) {
      // Silence leads to retry
      _handleLowConfidence(RecognitionResult(
        text: '',
        alternatives: [],
        confidence: 0.0,
        isFinal: true,
      ));
    } else if (_state == VoiceSessionState.confirming) {
      // Silence during confirmation is treated as unclear answer
      _handleConfirmationResponse(RecognitionResult(
        text: '',
        alternatives: [],
        confidence: 0.0,
        isFinal: true,
      ));
    }
  }

  // Danger alert during listening cancels session and danger message is spoken first
  void handleDangerAlert([String dangerMessage = 'Obstacle ahead']) {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    _recognizer.stop();
    _speechCenter.resume();
    _state = VoiceSessionState.idle;
    _retryState = RetryState.none;
    _speechCenter.speak(dangerMessage, priority: SpeechPriority.danger);
  }

  // Getters for testing
  VoiceSessionState get state => _state;
  RetryState get retryState => _retryState;
  int get retryCount => _retryCount;
  String? get lastPrompt => _lastPrompt;
}
