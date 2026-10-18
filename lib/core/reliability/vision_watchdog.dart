import 'dart:async';
import '../../data/vision/native_vision_bridge.dart';
import '../../data/tts_stt/tts_service.dart';
import '../../domain/models/alert_item.dart';

/// Watchdog that monitors visual analysis continuity.
/// If no frame analysis completes for 2.0 seconds while active,
/// the watchdog restarts the vision pipeline and alerts the user verbally.
class VisionWatchdog {
  final VisionBridge visionBridge;
  final TtsService ttsService;
  final Duration timeoutDuration;

  Timer? _watchdogTimer;
  int _lastHeartbeatMs = 0;
  bool _isActive = false;

  VisionWatchdog({
    required this.visionBridge,
    required this.ttsService,
    this.timeoutDuration = const Duration(milliseconds: 2000),
  });

  void start() {
    _isActive = true;
    _lastHeartbeatMs = DateTime.now().millisecondsSinceEpoch;
    _scheduleCheck();
  }

  void notifyFrameProcessed() {
    _lastHeartbeatMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _scheduleCheck() {
    _watchdogTimer?.cancel();
    if (!_isActive) return;

    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isActive) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - _lastHeartbeatMs;

      if (elapsed >= timeoutDuration.inMilliseconds) {
        // Heartbeat lapsed!
        _lastHeartbeatMs = now; // Prevent duplicate restart triggers
        await _handleWatchdogLapse();
      }
    });
  }

  Future<void> _handleWatchdogLapse() async {
    // 1. Spoken feedback to user: Never silent!
    await ttsService.speak(
      'Vision paused. Restarting camera.',
      priority: AlertPriority.p0Danger,
    );

    // 2. Restart vision pipeline
    try {
      await visionBridge.stopVision();
      await Future.delayed(const Duration(milliseconds: 200));
      await visionBridge.startVision();
    } catch (_) {}
  }

  void stop() {
    _isActive = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
}
