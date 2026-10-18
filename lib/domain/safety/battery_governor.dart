import 'dart:async';
import '../../data/vision/native_vision_bridge.dart';
import '../../data/tts_stt/tts_service.dart';
import '../models/alert_item.dart';

/// Battery governor monitoring device battery state.
/// When battery drops below 15%, disables camera ML inference to extend battery life,
/// announces the change verbally, and keeps physical sensors and vibration alerts active.
class BatteryGovernor {
  final VisionBridge visionBridge;
  final TtsService ttsService;

  bool _isLowBatteryMode = false;
  bool get isLowBatteryMode => _isLowBatteryMode;

  BatteryGovernor({
    required this.visionBridge,
    required this.ttsService,
  });

  Future<void> onBatteryLevelChanged(int batteryPercentage) async {
    if (batteryPercentage < 15 && !_isLowBatteryMode) {
      _isLowBatteryMode = true;
      await visionBridge.stopVision();
      await ttsService.speak(
        'Battery low. Camera turned off. Continuing with cane and vibration alerts.',
        priority: AlertPriority.p0Danger,
      );
    } else if (batteryPercentage >= 20 && _isLowBatteryMode) {
      _isLowBatteryMode = false;
      await visionBridge.startVision();
      await ttsService.speak(
        'Battery restored. Camera obstacle detection resumed.',
        priority: AlertPriority.p1Navigation,
      );
    }
  }
}
