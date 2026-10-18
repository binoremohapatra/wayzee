import 'dart:async';
import '../ui/feedback.dart';

enum SpeechPriority {
  danger, // Priority 0 - Always interrupts
  turn, // Priority 1 - Navigation turn
  information, // Priority 2 - General info
}

class SpeechItem {
  final String text;
  final SpeechPriority priority;
  final DateTime timestamp;

  SpeechItem({
    required this.text,
    required this.priority,
  }) : timestamp = DateTime.now();
}

class SpeechCenter {
  // Singleton
  static final SpeechCenter _instance = SpeechCenter._internal();
  factory SpeechCenter() => _instance;
  SpeechCenter._internal();

  // Priority queue (0 = highest, 2 = lowest)
  final List<SpeechItem> _queue = [];
  
  // Configuration
  static const int maxQueueSize = 3;
  static const Duration repeatSuppression = Duration(seconds: 4);
  static const Duration infoDropAge = Duration(seconds: 5);
  
  // State
  String? _lastSpoken;
  DateTime? _lastSpokenTime;
  bool _isPaused = false;
  bool _isSpeaking = false;
  Timer? _speakTimer;

  // Speak with priority
  void speak(String text, {SpeechPriority priority = SpeechPriority.information}) {
    if (_isPaused && priority != SpeechPriority.danger) {
      // Queue non-danger speech when paused
      _addToQueue(text, priority);
      return;
    }

    // Check repeat suppression
    if (_isRepeat(text)) {
      return; // Suppress repeats within 4 seconds
    }

    // Urgent speech interrupts current
    if (priority == SpeechPriority.danger && _isSpeaking) {
      _cancelCurrentSpeech();
    }

    // Drop old information messages
    _dropOldInfo();

    // Add to queue
    _addToQueue(text, priority);

    // Process queue
    _processQueue();
  }

  // Add to queue with size limit
  void _addToQueue(String text, SpeechPriority priority) {
    if (_queue.length >= maxQueueSize) {
      // Remove lowest priority item
      _queue.removeWhere((item) => item.priority == SpeechPriority.information);
      if (_queue.length >= maxQueueSize) {
        _queue.removeAt(_queue.length - 1); // Remove oldest
      }
    }
    _queue.add(SpeechItem(text: text, priority: priority));
  }

  // Process queue
  void _processQueue() {
    if (_isSpeaking || _queue.isEmpty) return;

    // Sort by priority (0 first)
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    final item = _queue.removeAt(0);
    _speakNow(item);
  }

  // Speak immediately
  void _speakNow(SpeechItem item) {
    _isSpeaking = true;
    _lastSpoken = item.text;
    _lastSpokenTime = DateTime.now();

    Fx.speak?.call(item.text);

    // Assume speech completes after a reasonable time
    // In real implementation, use TTS completion callback
    _speakTimer = Timer(const Duration(milliseconds: 100), () {
      _isSpeaking = false;
      _processQueue();
    });
  }

  // Cancel current speech
  void _cancelCurrentSpeech() {
    _speakTimer?.cancel();
    _isSpeaking = false;
    // In real implementation, call TTS stop
  }

  // Check if repeat
  bool _isRepeat(String text) {
    if (_lastSpoken == null || _lastSpokenTime == null) return false;
    if (_lastSpoken == text) {
      final elapsed = DateTime.now().difference(_lastSpokenTime!);
      return elapsed < repeatSuppression;
    }
    return false;
  }

  // Drop old information messages
  void _dropOldInfo() {
    final now = DateTime.now();
    _queue.removeWhere((item) {
      if (item.priority == SpeechPriority.information) {
        final age = now.difference(item.timestamp);
        return age > infoDropAge;
      }
      return false;
    });
  }

  // Pause for listening
  void pauseForListening() {
    _isPaused = true;
    _cancelCurrentSpeech();
  }

  // Resume
  void resume() {
    _isPaused = false;
    _processQueue();
  }

  // Repeat last spoken
  void repeatLast() {
    if (_lastSpoken != null) {
      speak(_lastSpoken!, priority: SpeechPriority.information);
    }
  }

  // Clear queue
  void clear() {
    _cancelCurrentSpeech();
    _queue.clear();
  }

  // Get queue size (for testing)
  int get queueSize => _queue.length;

  // Get paused state (for testing)
  bool get isPaused => _isPaused;

  // Get speaking state (for testing)
  bool get isSpeaking => _isSpeaking;
}
