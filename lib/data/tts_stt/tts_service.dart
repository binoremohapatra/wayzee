import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/models/alert_item.dart';

/// Contract for text-to-speech audio delivery.
abstract class TtsService {
  Future<void> initialize({
    String language = 'en-US',
    double speechRate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  });

  /// Speaks the given [text]. If [priority] is [AlertPriority.p0Danger], any current
  /// utterance must be stopped/interrupted immediately.
  Future<void> speak(String text, {AlertPriority priority = AlertPriority.p2Info});

  /// Immediately interrupts ongoing speech.
  Future<void> interrupt();

  /// Stops current speech output and clears pending speech.
  Future<void> stop();

  bool get isSpeaking;
  bool get isInitialized;
  Stream<bool> get speakingStateStream;
  void dispose();
}

/// Production implementation using on-device Flutter TTS.
class FlutterTtsService implements TtsService {
  final FlutterTts _flutterTts;
  final StreamController<bool> _speakingStateController =
      StreamController<bool>.broadcast();

  bool _isSpeaking = false;
  bool _isInitialized = false;

  FlutterTtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get speakingStateStream => _speakingStateController.stream;

  @override
  Future<void> initialize({
    String language = 'en-US',
    double speechRate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);

      // Prefer on-device Google TTS engine on Android
      try {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setEngine('com.google.android.tts');
      } catch (_) {
        // Fall back to default engine if Google TTS package is missing
      }

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _speakingStateController.add(true);
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      _flutterTts.setErrorHandler((_) {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  @override
  Future<void> speak(String text, {AlertPriority priority = AlertPriority.p2Info}) async {
    if (text.trim().isEmpty) return;

    if (priority.isDanger && _isSpeaking) {
      await interrupt();
    }

    _isSpeaking = true;
    _speakingStateController.add(true);
    await _flutterTts.speak(text);
  }

  @override
  Future<void> interrupt() async {
    _isSpeaking = false;
    _speakingStateController.add(false);
    await _flutterTts.stop();
  }

  @override
  Future<void> stop() async {
    await interrupt();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speakingStateController.close();
  }
}

/// Deterministic mock TTS service for unit and widget testing.
class MockTtsService implements TtsService {
  final List<String> spokenUtterances = [];
  final List<AlertPriority> spokenPriorities = [];
  final StreamController<bool> _stateController = StreamController<bool>.broadcast();

  bool _isSpeaking = false;
  bool _isInitialized = false;
  int interruptCount = 0;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get speakingStateStream => _stateController.stream;

  @override
  Future<void> initialize({
    String language = 'en-US',
    double speechRate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    _isInitialized = true;
  }

  @override
  Future<void> speak(String text, {AlertPriority priority = AlertPriority.p2Info}) async {
    if (priority.isDanger && _isSpeaking) {
      await interrupt();
    }
    _isSpeaking = true;
    _stateController.add(true);
    spokenUtterances.add(text);
    spokenPriorities.add(priority);
  }

  /// Simulates speech completion in unit tests
  void simulateCompletion() {
    _isSpeaking = false;
    _stateController.add(false);
  }

  @override
  Future<void> interrupt() async {
    interruptCount++;
    _isSpeaking = false;
    _stateController.add(false);
  }

  @override
  Future<void> stop() async {
    await interrupt();
  }

  void clear() {
    spokenUtterances.clear();
    spokenPriorities.clear();
    interruptCount = 0;
    _isSpeaking = false;
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
