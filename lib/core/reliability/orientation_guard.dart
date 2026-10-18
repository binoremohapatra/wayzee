import '../../data/tts_stt/tts_service.dart';
import '../../domain/models/alert_item.dart';

/// Monitors camera orientation from phone/cane tilt angle.
/// If the phone is slipped into a pocket (pointing straight down > 75 deg)
/// or pointed at the ceiling (< 15 deg), it prompts the user verbally.
class OrientationGuard {
  final TtsService ttsService;
  final Duration warningCooldown;

  DateTime? _lastWarningTime;

  OrientationGuard({
    required this.ttsService,
    this.warningCooldown = const Duration(seconds: 15),
  });

  void checkOrientation(double pitchAngleDeg, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (_lastWarningTime != null) {
      if (currentTime.difference(_lastWarningTime!) < warningCooldown) {
        return; // Suppressed by cooldown
      }
    }

    // Camera facing straight down into pocket or ground (> 75 degrees)
    if (pitchAngleDeg > 75.0) {
      _lastWarningTime = currentTime;
      ttsService.speak(
        'Phone ko seene pe seedha rakho. Camera aage dekh sake.',
        priority: AlertPriority.p1Navigation,
      );
    } else if (pitchAngleDeg < 15.0) {
      // Camera tilted towards ceiling
      _lastWarningTime = currentTime;
      ttsService.speak(
        'Phone ko aage seedha pakdo.',
        priority: AlertPriority.p2Info,
      );
    }
  }

  void reset() {
    _lastWarningTime = null;
  }
}
