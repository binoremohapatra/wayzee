import 'dart:async';
import '../alerts/alert_queue.dart';
import '../models/alert_item.dart';
import '../models/spatial_zone.dart';
import '../vision/vision_tracker.dart';
import 'sensor_source.dart';
import '../../core/accessibility/haptic_service.dart';

/// Sensor and Vision Fusion Engine.
/// Fuses optical bounding box detections with real-time distance telemetry.
/// In Phone-Only mode: NO centimeters are spoken to avoid false precision.
class FusionEngine {
  final AlertQueue alertQueue;
  final VisionTracker visionTracker;
  final HapticService hapticService;

  final double expectedDownDistanceCm;
  final double dropOffThresholdCm;
  final double frontObstacleThresholdCm;

  int _consecutiveDropOffCount = 0;
  int _consecutiveFrontObstacleCount = 0;
  SensorReading? _lastSensorReading;

  StreamSubscription<SensorReading>? _sensorSubscription;

  FusionEngine({
    required this.alertQueue,
    required this.visionTracker,
    this.hapticService = const SystemHapticService(),
    this.expectedDownDistanceCm = 110.0,
    this.dropOffThresholdCm = 35.0,
    this.frontObstacleThresholdCm = 50.0,
  });

  bool get isCaneConnected => _lastSensorReading?.isCaneConnected ?? false;

  void attachSensorSource(SensorSource source) {
    _sensorSubscription?.cancel();
    _sensorSubscription = source.readingStream.listen(ingestSensorReading);
  }

  /// Evaluates distance telemetry rules (drop-off, imminent front collision, glass doors)
  void ingestSensorReading(SensorReading reading) {
    _lastSensorReading = reading;
    final now = reading.timestamp;

    // 1. Drop-off / Stairs-down rule:
    // If downward distance exceeds expected ground baseline by threshold for >= 2 consecutive readings
    final isDropOffSample = reading.downDistanceCm > (expectedDownDistanceCm + dropOffThresholdCm);
    if (isDropOffSample) {
      _consecutiveDropOffCount++;
      if (_consecutiveDropOffCount >= 2) {
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
      String formattedSpeech = alert.speechText;

      // Phone-only mode rule: Never speak centimeters, only "near" or "ahead"
      if (!isCane && alert.priority != AlertPriority.p0Danger) {
        final zonePhrase = alert.zone?.spokenLabel ?? 'directly ahead';
        formattedSpeech = '${alert.label} $zonePhrase, near.';
      }

      // Cross-reference with sensor distance if cane is connected
      final effectiveDistance = (alert.zone == SpatialZone.center && _lastSensorReading != null && isCane)
          ? (_lastSensorReading!.frontDistanceCm / 100.0)
          : alert.distanceMeters;

      final fusedAlert = AlertItem(
        id: alert.id,
        label: alert.label,
        speechText: formattedSpeech,
        priority: alert.priority,
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
