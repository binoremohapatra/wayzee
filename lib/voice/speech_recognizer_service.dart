import 'dart:async';

class RecognitionResult {
  final String text;
  final List<String> alternatives;
  final double confidence;
  final bool isFinal;

  RecognitionResult({
    required this.text,
    required this.alternatives,
    required this.confidence,
    required this.isFinal,
  });
}

enum RecognitionError {
  noPermission,
  noMicrophone,
  networkError,
  timeout,
  unknown,
}

abstract class SpeechRecognizerService {
  // Initialize the recognizer
  Future<void> initialize();

  // Start listening with grammar hint list
  Stream<RecognitionResult> listen({
    List<String>? grammarHints,
    Duration? maxDuration,
  });

  // Stop listening
  Future<void> stop();

  // Dispose resources
  Future<void> dispose();
}

// Fake recognizer for testing
class FakeRecognizer implements SpeechRecognizerService {
  final List<RecognitionResult> _scriptedResults;
  int _scriptIndex = 0;
  final bool _simulateLowConfidence;
  final bool _simulateSilence;
  final bool _simulateError;
  final RecognitionError? _errorType;
  final Duration? _resultDelay;
  final bool _immediate; // For testing: deliver results immediately without real delay

  bool _isListening = false;
  StreamController<RecognitionResult>? _onDemandController;

  FakeRecognizer({
    List<RecognitionResult>? scriptedResults,
    this._simulateLowConfidence = false,
    this._simulateSilence = false,
    this._simulateError = false,
    this._errorType,
    this._resultDelay,
    this._immediate = false,
  })  : _scriptedResults = scriptedResults ?? [];

  @override
  Future<void> initialize() async {
    if (!_immediate) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Stream<RecognitionResult> listen({
    List<String>? grammarHints,
    Duration? maxDuration,
  }) {
    _isListening = true;
    return _listenStream();
  }

  Stream<RecognitionResult> _listenStream() async* {
    if (_simulateError) {
      if (!_immediate) await Future.delayed(const Duration(milliseconds: 10));
      _isListening = false;
      throw _createError();
    }

    if (_simulateSilence) {
      if (!_immediate) await Future.delayed(const Duration(milliseconds: 10));
      _isListening = false;
      return;
    }

    if (_scriptIndex < _scriptedResults.length) {
      final result = _scriptedResults[_scriptIndex++];
      if (!_immediate) {
        await Future.delayed(_resultDelay ?? const Duration(milliseconds: 10));
      }
      _isListening = false;
      yield _simulateLowConfidence
          ? RecognitionResult(
              text: result.text,
              alternatives: result.alternatives,
              confidence: 0.3,
              isFinal: result.isFinal,
            )
          : result;
    } else {
      // Listen on demand if scripted results are empty or exhausted
      final controller = StreamController<RecognitionResult>();
      _onDemandController = controller;
      yield* controller.stream;
    }

    _isListening = false;
  }

  /// Deliver scripted result on demand in tests
  void deliverResult(RecognitionResult result) {
    if (_onDemandController != null && !_onDemandController!.isClosed) {
      _isListening = false;
      _onDemandController!.add(result);
      _onDemandController!.close();
    }
  }

  /// Deliver silence on demand in tests
  void deliverSilence() {
    if (_onDemandController != null && !_onDemandController!.isClosed) {
      _isListening = false;
      _onDemandController!.close();
    }
  }

  /// Deliver error on demand in tests
  void deliverError([Object? error]) {
    if (_onDemandController != null && !_onDemandController!.isClosed) {
      _isListening = false;
      _onDemandController!.addError(error ?? _createError());
      _onDemandController!.close();
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    if (_onDemandController != null && !_onDemandController!.isClosed) {
      await _onDemandController!.close();
    }
  }

  @override
  Future<void> dispose() async {
    _isListening = false;
    if (_onDemandController != null && !_onDemandController!.isClosed) {
      await _onDemandController!.close();
    }
  }

  Exception _createError() {
    switch (_errorType) {
      case RecognitionError.noPermission:
        return Exception('No microphone permission');
      case RecognitionError.noMicrophone:
        return Exception('No microphone available');
      case RecognitionError.networkError:
        return Exception('Network error');
      case RecognitionError.timeout:
        return Exception('Timeout');
      default:
        return Exception('Unknown recognition error');
    }
  }

  // Testing helpers
  bool get isListening => _isListening;
  int get scriptIndex => _scriptIndex;
}
