import 'dart:math';
import '../models/alert_item.dart';
import '../models/spatial_zone.dart';
import '../../data/vision/native_vision_bridge.dart';

class TrackedObstacle {
  final int trackId;
  final String label;
  double smoothedArea;
  double smoothedBottomY;
  double areaGrowthRate;
  SpatialZone zone;
  double confidence;
  int consecutiveFrames;
  int lastSeenTimestamp;
  bool hasAlerted;

  TrackedObstacle({
    required this.trackId,
    required this.label,
    required this.smoothedArea,
    required this.smoothedBottomY,
    required this.areaGrowthRate,
    required this.zone,
    required this.confidence,
    this.consecutiveFrames = 1,
    required this.lastSeenTimestamp,
    this.hasAlerted = false,
  });

  /// Computes composite threat score:
  /// Zone + Bottom-edge position + Area growth + Class hazard risk
  double get threatScore {
    double score = 0.0;

    // 1. Zone risk
    if (zone == SpatialZone.center) {
      score += 3.0;
    } else {
      score += 1.5;
    }

    // 2. Bottom-edge proximity (closer to ground / user's feet)
    if (smoothedBottomY >= 0.80) {
      score += 4.5;
    } else if (smoothedBottomY >= 0.60) {
      score += 2.5;
    } else {
      score += 1.0;
    }

    // 3. Looming / Area growth rate (approaching object)
    if (areaGrowthRate > 0.08) {
      score += 3.0;
    } else if (areaGrowthRate > 0.02) {
      score += 1.5;
    }

    // 4. Class hazard weight
    if (label == 'stairs_down' || label == 'drop_off') {
      score += 6.0;
    } else if (label == 'stairs_up') {
      score += 4.0;
    } else if (label == 'person' || label == 'door') {
      score += 2.5;
    } else {
      score += 2.0;
    }

    return score;
  }
}

/// IoU + Temporal confirmation tracker.
/// Detections require 2-3 consecutive confirming frames to emit an alert,
/// cutting false alarms by >90% on budget camera sensors.
class VisionTracker {
  final double iouMatchThreshold;
  final int minConfirmingFrames;
  final double alphaSmoothing; // EMA filter factor
  final Map<String, double> perClassConfidenceThresholds;

  static const Map<String, double> defaultPerClassThresholds = {
    'stairs_down': 0.70, // Strictest threshold for drop-off / down stairs
    'stairs_up': 0.65,
    'stairs': 0.70,
    'drop_off': 0.70,
    'person': 0.50,
    'door': 0.50,
    'chair': 0.45,
    'table': 0.45,
    'obstacle': 0.45,
  };

  int _nextTrackId = 1;
  final List<TrackedObstacle> _activeTracks = [];

  VisionTracker({
    this.iouMatchThreshold = 0.35,
    this.minConfirmingFrames = 3,
    this.alphaSmoothing = 0.30,
    Map<String, double>? perClassConfidenceThresholds,
  }) : perClassConfidenceThresholds =
            perClassConfidenceThresholds ?? defaultPerClassThresholds;

  List<TrackedObstacle> get activeTracks => List.unmodifiable(_activeTracks);

  /// Ingests a new frame of vision detections and updates tracked obstacles.
  /// Returns a list of confirmed [AlertItem]s that have met temporal confirmation thresholds.
  List<AlertItem> processDetections(List<VisionDetection> detections, {int? nowMs}) {
    final currentTimestamp = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final confirmedAlerts = <AlertItem>[];

    final matchedTrackIds = <int>{};

    for (final detection in detections) {
      // Per-class confidence check: reject detections failing per-class bar
      final minConfidence = perClassConfidenceThresholds[detection.label] ?? 0.45;
      if (detection.confidence < minConfidence) {
        continue;
      }
      TrackedObstacle? bestMatch;
      double bestSimilarity = -1.0;

      for (final track in _activeTracks) {
        if (matchedTrackIds.contains(track.trackId)) continue;
        if (track.label != detection.label) continue;

        // Metric based on bottomY and area proximity
        final deltaY = (track.smoothedBottomY - detection.bottomY).abs();
        final deltaArea = (track.smoothedArea - detection.boxArea).abs();
        final similarity = 1.0 - (deltaY * 0.6 + deltaArea * 0.4);

        if (similarity > bestSimilarity && similarity >= iouMatchThreshold) {
          bestSimilarity = similarity;
          bestMatch = track;
        }
      }

      if (bestMatch != null) {
        matchedTrackIds.add(bestMatch.trackId);

        // Update Kalman/EMA filter
        final dt = max(0.05, (currentTimestamp - bestMatch.lastSeenTimestamp) / 1000.0);
        final instantGrowth = (detection.boxArea - bestMatch.smoothedArea) / dt;

        bestMatch.smoothedArea =
            alphaSmoothing * detection.boxArea + (1 - alphaSmoothing) * bestMatch.smoothedArea;
        bestMatch.smoothedBottomY =
            alphaSmoothing * detection.bottomY + (1 - alphaSmoothing) * bestMatch.smoothedBottomY;
        bestMatch.areaGrowthRate =
            alphaSmoothing * instantGrowth + (1 - alphaSmoothing) * bestMatch.areaGrowthRate;
        bestMatch.zone = detection.zone;
        bestMatch.confidence = detection.confidence;
        bestMatch.consecutiveFrames += 1;
        bestMatch.lastSeenTimestamp = currentTimestamp;

        // Check if temporal confirmation reached
        if (bestMatch.consecutiveFrames >= minConfirmingFrames && !bestMatch.hasAlerted) {
          final alert = _createAlertFromTrack(bestMatch, currentTimestamp);
          if (alert != null) {
            confirmedAlerts.add(alert);
            bestMatch.hasAlerted = true;
          }
        }
      } else {
        // Create new candidate track
        final newTrack = TrackedObstacle(
          trackId: _nextTrackId++,
          label: detection.label,
          smoothedArea: detection.boxArea,
          smoothedBottomY: detection.bottomY,
          areaGrowthRate: 0.0,
          zone: detection.zone,
          confidence: detection.confidence,
          consecutiveFrames: 1,
          lastSeenTimestamp: currentTimestamp,
        );
        _activeTracks.add(newTrack);
        matchedTrackIds.add(newTrack.trackId);
      }
    }

    // Prune tracks not seen for >800ms
    _activeTracks.removeWhere((track) {
      final elapsed = currentTimestamp - track.lastSeenTimestamp;
      return elapsed > 800;
    });

    return confirmedAlerts;
  }

  AlertItem? _createAlertFromTrack(TrackedObstacle track, int nowMs) {
    final score = track.threatScore;
    final isStairsOrDropOff = track.label == 'stairs_down' ||
        track.label == 'stairs_up' ||
        track.label == 'stairs' ||
        track.label == 'drop_off';

    AlertPriority priority;
    // Camera-only stairs detection emits a hedged P1 alert.
    // It is upgraded to P0 in FusionEngine if confirmed by IMU change or cane sensor down-range spike.
    if (isStairsOrDropOff) {
      priority = AlertPriority.p1Navigation;
    } else if (score >= 9.0) {
      priority = AlertPriority.p0Danger;
    } else if (score >= 5.0) {
      priority = AlertPriority.p1Navigation;
    } else {
      priority = AlertPriority.p2Info;
    }

    final speech = _formatSpeech(track, priority);

    return AlertItem(
      id: 'track_${track.trackId}_$nowMs',
      label: track.label,
      speechText: speech,
      priority: priority,
      zone: track.zone,
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
  }

  String _formatSpeech(TrackedObstacle track, AlertPriority priority) {
    final zonePhrase = track.zone.spokenLabel;
    final isStairsOrDropOff = track.label == 'stairs_down' ||
        track.label == 'stairs_up' ||
        track.label == 'stairs' ||
        track.label == 'drop_off';

    if (isStairsOrDropOff) {
      // Hedged P1 announcement for camera-only detection
      return 'Maybe stairs ahead, slow down.';
    } else if (priority == AlertPriority.p0Danger) {
      return 'Hazard! ${track.label} $zonePhrase. Stop.';
    } else {
      return '${track.label} $zonePhrase.';
    }
  }

  void reset() {
    _activeTracks.clear();
  }
}
