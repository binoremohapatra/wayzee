import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/alerts/alert_queue.dart';
import '../domain/models/alert_item.dart';
import '../data/tts_stt/tts_service.dart';
import '../core/accessibility/haptic_service.dart';

/// Provider for the application's Text-to-Speech service.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = FlutterTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for haptic feedback.
final hapticServiceProvider = Provider<HapticService>((ref) {
  return const SystemHapticService();
});

/// State controller managing AlertQueue dispatching and synchronization with TTS and haptics.
class AlertQueueController extends StateNotifier<List<AlertItem>> {
  final AlertQueue _queue;
  final TtsService _ttsService;
  final HapticService _hapticService;

  AlertQueueController({
    required AlertQueue queue,
    required TtsService ttsService,
    required HapticService hapticService,
  })  : _queue = queue,
        _ttsService = ttsService,
        _hapticService = hapticService,
        super([]) {
    // Listen to TTS speaking state to pump next alerts when speech completes
    _ttsService.speakingStateStream.listen((isSpeaking) {
      if (!isSpeaking) {
        processNextAlert();
      }
    });
  }

  /// Enqueue an alert and process queue
  bool postAlert(AlertItem item) {
    final accepted = _queue.enqueue(item);
    state = _queue.queuedItems;

    if (accepted) {
      processNextAlert();
    }
    return accepted;
  }

  /// Processes the next scheduled alert based on priority and TTS status
  Future<void> processNextAlert() async {
    final item = _queue.pollNext(isTtsIdle: !_ttsService.isSpeaking);
    state = _queue.queuedItems;

    if (item != null) {
      if (item.priority == AlertPriority.p0Danger) {
        await _hapticService.danger();
        await _ttsService.speak(item.text, priority: AlertPriority.p0Danger);
      } else {
        await _ttsService.speak(item.text, priority: item.priority);
      }
    }
  }

  void clear() {
    _queue.clear();
    state = [];
  }
}

/// Provider for the AlertQueue state controller.
final alertQueueProvider =
    StateNotifierProvider<AlertQueueController, List<AlertItem>>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptics = ref.watch(hapticServiceProvider);

  final queue = AlertQueue(
    onP0DangerTriggered: (dangerItem) {
      haptics.danger();
      tts.speak(dangerItem.text, priority: AlertPriority.p0Danger);
    },
  );

  return AlertQueueController(
    queue: queue,
    ttsService: tts,
    hapticService: haptics,
  );
});
