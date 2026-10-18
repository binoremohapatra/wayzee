import '../detector/detector.dart';
import '../detector/zone.dart';
import '../safety/cane_sensor.dart';

class FusionResult {
  final String sentence;
  final bool isUrgent;
  final int priority; // 0 = info, 1 = turn, 2 = danger

  FusionResult({
    required this.sentence,
    this.isUrgent = false,
    this.priority = 0,
  });
}

class FusionEngine {
  static FusionResult generateSentence({
    required Detection? detection,
    required Zone zone,
    required CaneSensorData caneData,
  }) {
    // Priority: danger > turn > info
    if (caneData.isDanger) {
      return _generateDangerAlert(caneData);
    }

    if (detection != null) {
      return _generateDetectionSentence(detection, zone, caneData);
    }

    // No detection, but check cane sensor
    if (caneData.isObstacleNear) {
      return _generateObstacleAlert(caneData);
    }

    // No meaningful input
    return FusionResult(
      sentence: 'Path clear',
      priority: 0,
    );
  }

  static FusionResult _generateDangerAlert(CaneSensorData caneData) {
    if (caneData.stairsAhead) {
      return FusionResult(
        sentence: 'Stairs ahead. Stop.',
        isUrgent: true,
        priority: 2,
      );
    }

    if (caneData.dropOffAhead) {
      return FusionResult(
        sentence: 'Drop-off ahead. Stop.',
        isUrgent: true,
        priority: 2,
      );
    }

    if (caneData.isObstacleVeryClose) {
      return FusionResult(
        sentence: 'Obstacle very close. Stop.',
        isUrgent: true,
        priority: 2,
      );
    }

    return FusionResult(
      sentence: 'Obstacle near. Slow down.',
      isUrgent: true,
      priority: 2,
    );
  }

  static FusionResult _generateDetectionSentence(
    Detection detection,
    Zone zone,
    CaneSensorData caneData,
  ) {
    final label = detection.label;
    final confidence = detection.confidence;
    final distance = _estimateDistance(caneData.distanceCm, confidence);

    // Format: "Label ahead, distance, zone"
    final distanceText = _formatDistance(distance);
    final zoneText = zone.label;

    final sentence = '$label ahead, $distanceText, $zoneText.';

    // Determine priority based on detection type
    int priority = 0;
    if (_isDangerousObject(label)) {
      priority = 2;
    } else if (_isTurnIndicator(label)) {
      priority = 1;
    }

    return FusionResult(
      sentence: sentence,
      priority: priority,
    );
  }

  static FusionResult _generateObstacleAlert(CaneSensorData caneData) {
    final distance = _formatDistance(caneData.distanceCm);
    return FusionResult(
      sentence: 'Obstacle $distance.',
      isUrgent: true,
      priority: 2,
    );
  }

  static double _estimateDistance(double caneDistance, double confidence) {
    // Simple estimation: use cane distance if available and confident
    // Otherwise, estimate from confidence (higher confidence = closer)
    if (caneDistance > 0 && confidence > 0.7) {
      return caneDistance;
    }
    // Fallback: estimate from confidence (0.3-3.0 meters)
    return (1.0 - confidence) * 3.0 * 100; // in cm
  }

  static String _formatDistance(double distanceCm) {
    final meters = distanceCm / 100;
    if (meters < 1.0) {
      return '${distanceCm.round()} centimetres';
    } else {
      return '${meters.toStringAsFixed(1)} metres';
    }
  }

  static bool _isDangerousObject(String label) {
    final dangerous = [
      'stairs',
      'glass_door',
      'wet_floor_sign',
      'escalator',
    ];
    return dangerous.any((d) => label.toLowerCase().contains(d));
  }

  static bool _isTurnIndicator(String label) {
    final turnIndicators = [
      'door',
      'elevator',
    ];
    return turnIndicators.any((t) => label.toLowerCase().contains(t));
  }
}
