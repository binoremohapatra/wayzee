import 'dart:async';
import '../../data/vision/native_vision_bridge.dart';
import '../../data/tts_stt/tts_service.dart';
import '../../domain/models/alert_item.dart';

enum DeviceThermalLevel {
  none(0, 10, 'Normal'),
  light(1, 10, 'Light'),
  moderate(2, 7, 'Moderate'),
  severe(3, 4, 'Severe'),
  critical(4, 2, 'Critical'),
  emergency(5, 1, 'Emergency');

  final int statusCode;
  final int targetFps;
  final String label;

  const DeviceThermalLevel(this.statusCode, this.targetFps, this.label);

  static DeviceThermalLevel fromCode(int code) {
    return DeviceThermalLevel.values.firstWhere(
      (e) => e.statusCode == code,
      orElse: () => DeviceThermalLevel.none,
    );
  }
}

/// Thermal Governor for budget Snapdragon 680 / Helio G85 devices.
/// Dynamically monitors PowerManager.getCurrentThermalStatus and scales inference FPS.
class ThermalGovernor {
  final VisionBridge visionBridge;
  final TtsService ttsService;
  Timer? _pollingTimer;

  DeviceThermalLevel _currentLevel = DeviceThermalLevel.none;
  DeviceThermalLevel get currentLevel => _currentLevel;

  ThermalGovernor({required this.visionBridge, required this.ttsService});

  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => checkThermalStatus());
  }

  Future<void> checkThermalStatus() async {
    final statusCode = await visionBridge.getThermalStatus();
    final newLevel = DeviceThermalLevel.fromCode(statusCode);

    if (newLevel != _currentLevel) {
      _currentLevel = newLevel;
      await _applyThermalPolicy(_currentLevel);
    }
  }

  Future<void> _applyThermalPolicy(DeviceThermalLevel level) async {
    switch (level) {
      case DeviceThermalLevel.none:
      case DeviceThermalLevel.light:
        await visionBridge.setStationary(false);
        break;
      case DeviceThermalLevel.moderate:
        await visionBridge.setStationary(true); // Drops to lower FPS
        break;
      case DeviceThermalLevel.severe:
        await visionBridge.setStationary(true);
        await ttsService.speak(
          'Phone temperature high. Reducing visual frame rate.',
          priority: AlertPriority.p2Info,
        );
        break;
      case DeviceThermalLevel.critical:
      case DeviceThermalLevel.emergency:
        await visionBridge.setStationary(true);
        await ttsService.speak(
          'Warning. Device overheating. Guidance running in battery conservation mode.',
          priority: AlertPriority.p0Danger,
        );
        break;
    }
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
