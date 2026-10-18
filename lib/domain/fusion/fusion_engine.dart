import 'dart:async';
import '../alerts/alert_queue.dart';
import '../models/alert_item.dart';
import '../models/spatial_zone.dart';
import '../vision/vision_tracker.dart';
import '../safety/camera_health_monitor.dart';
import 'sensor_source.dart';
import '../../core/accessibility/haptic_service.dart';

/// Sensor and Vision Fusion Engine.
/// Fuses optical bounding box detections with real-time distance telemetry.
/// In Phone-Only mode: NO centimeters are spoken to avoid false precision.
class FusionEngine {
  final AlertQueue alertQueue;
  final VisionTracker visionTracker;
  final HapticService hapticService;
  final CameraHealthMonitor? cameraHealthMonitor;

  final double expectedDownDistanceCm;
  final double dropOffThresholdCm;
  final double frontObstacleThresholdCm;
  final Duration stairsConfirmationWindow;
  final double imuPitchChangeThresholdDeg;

  int _consecutiveDropOffCount = 0;
  int _consecutiveFrontObstacleCount = 0;
  SensorReading? _lastSensorReading;

  DateTime? _lastCameraStairsTimestamp;
  DateTime? _lastSensorSpikeTimestamp;
  DateTime? _lastImuChangeTimestamp;
  double? _baselinePitchDeg;

  StreamSubscription<SensorReading>? _sensorSubscription;

  FusionEngine({
    required this.alertQueue,
    required this.visionTracker,
    this.hapticService = const SystemHapticService(),
    this.cameraHealthMonitor,
    this.expectedDownDistanceCm = 110.0,
    this.dropOffThresholdCm = 35.0,
    this.frontObstacleThresholdCm = 50.0,
    this.stairsConfirmationWindow = const Duration(milliseconds: 1500),
    this.imuPitchChangeThresholdDeg = 10.0,
  });

  bool get isCaneConnected => _lastSensorReading?.isCaneConnected ?? false;

  void ingestCameraHealth(CameraFrameHealth health, {DateTime? now}) {
    cameraHealthMonitor?.evaluateFrame(
      frameHealth: health,
      pitchAngleDeg: _lastSensorReading?.pitchAngleDeg,
      rollAngleDeg: _lastSensorReading?.rollAngleDeg,
      now: now,
    );
  }

  void attachSensorSource(SensorSource source) {
    _sensorSubscription?.cancel();
    _sensorSubscription = source.readingStream.listen(ingestSensorReading);
  }

  /// Evaluates distance telemetry rules (drop-off, imminent front collision, glass doors)
  void ingestSensorReading(SensorReading reading) {
    _lastSensorReading = reading;
    final now = reading.timestamp;

    // 0. Update baseline pitch and track IMU tilt changes
    if (_baselinePitchDeg == null) {
      _baselinePitchDeg = reading.pitchAngleDeg;
    } else {
      final pitchDelta = (reading.pitchAngleDeg - _baselinePitchDeg!).abs();
      if (pitchDelta >= imuPitchChangeThresholdDeg) {
        _lastImuChangeTimestamp = now;
        // Two-stage confirmation: Camera stairs + IMU tilt change within window
        if (_lastCameraStairsTimestamp != null &&
            now.difference(_lastCameraStairsTimestamp!) <= stairsConfirmationWindow) {
          final alert = AlertItem(
            id: 'stairs_confirmed_imu_${now.millisecondsSinceEpoch}',
            label: 'stairs_down',
            speechText: 'Stairs ahead. Stop.',
            priority: AlertPriority.p0Danger,
            zone: SpatialZone.center,
            distanceMeters: 0.5,
            timestamp: now,
          );
          hapticService.danger();
          alertQueue.enqueue(alert, now: now);
        }
      } else {
        // Slowly drift baseline when stable
        _baselinePitchDeg = 0.95 * _baselinePitchDeg! + 0.05 * reading.pitchAngleDeg;
      }
    }

    // 1. Drop-off / Stairs-down rule:
    // If downward distance exceeds expected ground baseline by threshold for >= 2 consecutive readings
    final isDropOffSample = reading.downDistanceCm > (expectedDownDistanceCm + dropOffThresholdCm);
    if (isDropOffSample) {
      _lastSensorSpikeTimestamp = now;
      _consecutiveDropOffCount++;

      // Two-stage confirmation: Camera stairs + Cane/mock down-range spike within window
      if (_lastCameraStairsTimestamp != null &&
          now.difference(_lastCameraStairsTimestamp!) <= stairsConfirmationWindow) {
        final alert = AlertItem(
          id: 'stairs_confirmed_sensor_${now.millisecondsSinceEpoch}',
          label: 'stairs_down',
          speechText: 'Stairs ahead. Stop.',
          priority: AlertPriority.p0Danger,
          zone: SpatialZone.center,
          distanceMeters: 0.5,
          timestamp: now,
        );
        hapticService.danger();
        alertQueue.enqueue(alert, now: now);
      } else if (_consecutiveDropOffCount >= 2) {
        // Cane-only drop-off confirmation (requires >= 2 consecutive readings; single frame spike ignored)
        final alert = AlertItem(
          id: 'dropoff_${now.millisecondsSinceEpoch}',
          label: 'stairs_down',
          speechText: 'Stairs down ahead. Stop.',
          priority: AlertPriority.p0Danger,
          zone: SpatialZone.center,
          distanceMeters: 0.5,
          timestamp: now,
        );
        hapticService.danger();
        alertQueue.enqueue(alert, now: now);
      }
    } else {
      _consecutiveDropOffCount = 0;
    }

    // 2. Obstacle < 50cm rule (also catches glass doors missed by camera):
    final isFrontObstacleSample = reading.frontDistanceCm < frontObstacleThresholdCm && reading.frontDistanceCm > 0;
    if (isFrontObstacleSample) {
      _consecutiveFrontObstacleCount++;
      if (_consecutiveFrontObstacleCount >= 2) {
        final alert = AlertItem(
          id: 'front_obst_${now.millisecondsSinceEpoch}',
          label: 'obstacle',
          speechText: 'Obstacle directly ahead. Stop.',
          priority: AlertPriority.p0Danger,
          zone: SpatialZone.center,
          distanceMeters: reading.isCaneConnected ? (reading.frontDistanceCm / 100.0) : null,
          timestamp: now,
        );
        hapticService.danger();
        alertQueue.enqueue(alert, now: now);
      }
    } else {
      _consecutiveFrontObstacleCount = 0;
    }
  }

  /// Ingests camera vision detections, runs tracker, and enqueues confirmed alerts
  List<AlertItem> ingestVisionDetections(List<dynamic> rawDetections, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    // Map detections into VisionTracker
    final confirmedAlerts = visionTracker.processDetections(
      rawDetections.cast(),
      nowMs: currentTime.millisecondsSinceEpoch,
    );

    for (final alert in confirmedAlerts) {
      final isCane = isCaneConnected;
      final isStairs = alert.label == 'stairs_down' ||
          alert.label == 'stairs_up' ||
          alert.label == 'stairs' ||
          alert.label == 'drop_off';

      String formattedSpeech = alert.speechText;
      AlertPriority effectivePriority = alert.priority;

      if (isStairs) {
        // Two-stage confirmation check:
        // Has there been an IMU tilt change or cane down-range spike within the window?
        final bool hasRecentSensorSpike = _lastSensorSpikeTimestamp != null &&
            currentTime.difference(_lastSensorSpikeTimestamp!) <= stairsConfirmationWindow;
        final bool hasRecentImuChange = _lastImuChangeTimestamp != null &&
            currentTime.difference(_lastImuChangeTimestamp!) <= stairsConfirmationWindow;

        if (hasRecentSensorSpike || hasRecentImuChange) {
          // Confirmed stairs: P0 Stop!
          formattedSpeech = 'Stairs ahead. Stop.';
          effectivePriority = AlertPriority.p0Danger;
        } else {
          // Camera-only stairs detection: Hedged P1 ("maybe stairs ahead, slow down")
          _lastCameraStairsTimestamp = currentTime;
          formattedSpeech = 'Maybe stairs ahead, slow down.';
          effectivePriority = AlertPriority.p1Navigation;
        }
      } else {
        // Phone-only mode rule for non-stairs: Never speak centimeters, only "near" or "ahead"
        if (!isCane && alert.priority != AlertPriority.p0Danger) {
          final zonePhrase = alert.zone?.spokenLabel ?? 'directly ahead';
          formattedSpeech = '${alert.label} $zonePhrase, near.';
        }
      }

      // Cross-reference with sensor distance if cane is connected
      final effectiveDistance = (alert.zone == SpatialZone.center && _lastSensorReading != null && isCane)
          ? (_lastSensorReading!.frontDistanceCm / 100.0)
          : alert.distanceMeters;

      final fusedAlert = AlertItem(
        id: alert.id,
        label: alert.label,
        speechText: formattedSpeech,
        priority: effectivePriority,
        zone: alert.zone,
        distanceMeters: effectiveDistance,
        timestamp: currentTime,
      );

      if (fusedAlert.priority == AlertPriority.p0Danger) {
        hapticService.danger();
      }

      alertQueue.enqueue(fusedAlert, now: currentTime);
    }

    return confirmedAlerts;
  }

  /// Handled when navigating into an unknown unmapped room
  void announceUnknownRoom() {
    alertQueue.enqueue(
      AlertItem(
        id: 'unknown_room_${DateTime.now().millisecondsSinceEpoch}',
        label: 'map_status',
        speechText: 'No map for this room. Live obstacle alerts active.',
        priority: AlertPriority.p1Navigation,
        zone: SpatialZone.center,
        timestamp: DateTime.now(),
      ),
    );
  }

  void reset() {
    _consecutiveDropOffCount = 0;
    _consecutiveFrontObstacleCount = 0;
    visionTracker.reset();
  }

  void dispose() {
    _sensorSubscription?.cancel();
  }
}
