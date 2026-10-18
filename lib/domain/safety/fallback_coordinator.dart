import 'dart:async';
import '../../core/accessibility/haptic_service.dart';
import '../../data/tts_stt/tts_service.dart';
import '../../data/vision/native_vision_bridge.dart';
import '../models/alert_item.dart';
import '../state/app_state_machine.dart';

enum FallbackTrigger {
  cameraCrash,
  bleLost,
  voskCrash,
  ttsFailure,
  mapCorrupt,
  phoneInPocket,
  fatalAppStop,
}

/// FallbackCoordinator implementing the exact fault-tolerance and failover table.
/// Failure messaging rule: "Nothing reported" must NEVER mean "safe".
/// Every failure is communicated by voice or distinct vibration pattern.
class FallbackCoordinator {
  final TtsService ttsService;
  final HapticService hapticService;
  final VisionBridge visionBridge;
  final AppStateMachine stateMachine;

  int _cameraRestartAttempts = 0;
  bool _isVisionPermanentlyDisabled = false;

  FallbackCoordinator({
    required this.ttsService,
    required this.hapticService,
    required this.visionBridge,
    required this.stateMachine,
  });

  bool get isVisionPermanentlyDisabled => _isVisionPermanentlyDisabled;

  /// Handles Camera/YOLO crash: restart up to 3 times, then fall back to sensor+map mode
  Future<void> handleCameraFailure() async {
    _cameraRestartAttempts++;
    if (_cameraRestartAttempts <= 3) {
      await ttsService.speak(
        'Vision error. Attempting restart $_cameraRestartAttempts of 3.',
        priority: AlertPriority.p0Danger,
      );
      try {
        await visionBridge.stopVision();
        await Future.delayed(const Duration(milliseconds: 300));
        await visionBridge.startVision();
      } catch (_) {}
    } else {
      _isVisionPermanentlyDisabled = true;
      await visionBridge.stopVision();
      await ttsService.speak(
        'Camera unavailable. Switched to smart cane and map mode.',
        priority: AlertPriority.p0Danger,
      );
    }
  }

  /// Handles Cane BLE disconnection
  Future<void> handleBleDisconnection() async {
    await hapticService.warning();
    await ttsService.speak(
      'Cane disconnected. Switched to phone-only mode.',
      priority: AlertPriority.p0Danger,
    );
  }

  /// Handles Voice recognizer (Vosk) failure
  Future<void> handleVoiceRecognizerCrash() async {
    await hapticService.warning();
    await ttsService.speak(
      'Voice recognition unavailable. Use volume keys or screen buttons.',
      priority: AlertPriority.p1Navigation,
    );
  }

  /// Handles TTS failure: communicates state via tactile vibration patterns
  Future<void> handleTtsFailure(AlertPriority priority) async {
    switch (priority) {
      case AlertPriority.p0Danger:
        // Long heavy vibration pattern for emergency stop
        await hapticService.danger();
        break;
      case AlertPriority.p1Navigation:
        // Double short pulse
        await hapticService.warning();
        break;
      case AlertPriority.p2Info:
        // Single confirmation tick
        await hapticService.click();
        break;
    }
  }

  /// Handles corrupt map file recovery
  Future<void> handleMapRestoredFromBackup() async {
    await ttsService.speak(
      'Map file was corrupted. Restored successfully from backup.',
      priority: AlertPriority.p1Navigation,
    );
  }

  /// Final fallback message before termination
  Future<void> emitFatalFallback() async {
    await hapticService.danger();
    try {
      await ttsService.speak(
        'Wayze has stopped. Use your cane.',
        priority: AlertPriority.p0Danger,
      );
    } catch (_) {
      // If audio completely dead, haptics have already triggered
    }
  }

  void reset() {
    _cameraRestartAttempts = 0;
    _isVisionPermanentlyDisabled = false;
  }
}
