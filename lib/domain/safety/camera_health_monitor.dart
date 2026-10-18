import '../alerts/alert_queue.dart';
import '../models/alert_item.dart';
import '../models/spatial_zone.dart';

/// Frame health metadata computed on-device (in RAM, zero frames saved or sent).
class CameraFrameHealth {
  final double meanLuminance;
  final double varianceLuminance;
  final bool isDark;
  final bool isBlocked;
  final DateTime timestamp;

  const CameraFrameHealth({
    required this.meanLuminance,
    required this.varianceLuminance,
    required this.isDark,
    required this.isBlocked,
    required this.timestamp,
  });
}

/// Evaluates camera visibility, physical blockage, and phone mounting angle.
/// Ensures voice guidance warns the user promptly while debouncing to avoid alert fatigue.
class CameraHealthMonitor {
  final AlertQueue alertQueue;
  final Duration cooldown;
  final int minConsecutiveFrames;

  int _consecutiveDarkFrames = 0;
  int _consecutiveBlockedFrames = 0;

  DateTime? _lastLowLightAlertTime;
  DateTime? _lastBlockedAlertTime;
  DateTime? _lastPocketAlertTime;

  CameraHealthMonitor({
    required this.alertQueue,
    this.cooldown = const Duration(seconds: 20),
    this.minConsecutiveFrames = 2,
  });

  int get consecutiveDarkFrames => _consecutiveDarkFrames;
  int get consecutiveBlockedFrames => _consecutiveBlockedFrames;

  /// Evaluates camera frame health along with current phone orientation.
  void evaluateFrame({
    required CameraFrameHealth frameHealth,
    double? pitchAngleDeg,
    double? rollAngleDeg,
    DateTime? now,
  }) {
    final currentTime = now ?? frameHealth.timestamp;

    // 1. Phone-in-pocket / bad angle heuristic:
    // If phone pitch indicates it is facing downward into pocket or pointing at ceiling (>65 deg tilt or <-40 deg)
    // combined with dark/blocked frame or extreme tilt angle
    final isPocketOrBadAngle = (pitchAngleDeg != null && pitchAngleDeg.abs() > 65.0) ||
        ((frameHealth.isDark || frameHealth.isBlocked) &&
            pitchAngleDeg != null &&
            pitchAngleDeg < -40.0);

    if (isPocketOrBadAngle) {
      if (_lastPocketAlertTime == null ||
          currentTime.difference(_lastPocketAlertTime!) >= cooldown) {
        _lastPocketAlertTime = currentTime;
        alertQueue.enqueue(
          AlertItem(
            id: 'pocket_${currentTime.millisecondsSinceEpoch}',
            label: 'phone_orientation',
            speechText: 'Place phone on your chest.',
            priority: AlertPriority.p1Navigation,
            zone: SpatialZone.center,
            timestamp: currentTime,
          ),
          now: currentTime,
        );
      }
      // Suppress lower-level dark/blocked alerts when in pocket or bad angle
      _consecutiveDarkFrames = 0;
      _consecutiveBlockedFrames = 0;
      return;
    }

    // 2. Blocked camera heuristic
    if (frameHealth.isBlocked) {
      _consecutiveBlockedFrames++;
      if (_consecutiveBlockedFrames >= minConsecutiveFrames) {
        if (_lastBlockedAlertTime == null ||
            currentTime.difference(_lastBlockedAlertTime!) >= cooldown) {
          _lastBlockedAlertTime = currentTime;
          alertQueue.enqueue(
            AlertItem(
              id: 'blocked_${currentTime.millisecondsSinceEpoch}',
              label: 'camera_blocked',
              speechText: 'Camera is blocked.',
              priority: AlertPriority.p1Navigation,
              zone: SpatialZone.center,
              timestamp: currentTime,
            ),
            now: currentTime,
          );
        }
      }
    } else {
      _consecutiveBlockedFrames = 0;
    }

    // 3. Low-light heuristic
    if (frameHealth.isDark) {
      _consecutiveDarkFrames++;
      if (_consecutiveDarkFrames >= minConsecutiveFrames) {
        if (_lastLowLightAlertTime == null ||
            currentTime.difference(_lastLowLightAlertTime!) >= cooldown) {
          _lastLowLightAlertTime = currentTime;
          alertQueue.enqueue(
            AlertItem(
              id: 'dark_${currentTime.millisecondsSinceEpoch}',
              label: 'low_light',
              speechText: 'Camera cannot see well, rely on your cane.',
              priority: AlertPriority.p1Navigation,
              zone: SpatialZone.center,
              timestamp: currentTime,
            ),
            now: currentTime,
          );
        }
      }
    } else {
      _consecutiveDarkFrames = 0;
    }
  }

  void reset() {
    _consecutiveDarkFrames = 0;
    _consecutiveBlockedFrames = 0;
    _lastLowLightAlertTime = null;
    _lastBlockedAlertTime = null;
    _lastPocketAlertTime = null;
  }
}
