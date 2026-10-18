import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/data/vision/native_vision_bridge.dart';
import 'package:wayze/domain/models/spatial_zone.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';

void main() {
  group('VisionTracker & Threat Scoring Tests', () {
    late VisionTracker tracker;

    setUp(() {
      tracker = VisionTracker(
        iouMatchThreshold: 0.35,
        minConfirmingFrames: 3,
        alphaSmoothing: 0.30,
      );
    });

    test('single frame does not emit alert (temporal confirmation suppresses false positive)', () {
      final detection = const VisionDetection(
        label: 'obstacle',
        confidence: 0.75,
        zone: SpatialZone.center,
        boxArea: 0.15,
        bottomY: 0.65,
        timestamp: 1000,
      );

      final alerts = tracker.processDetections([detection], nowMs: 1000);
      expect(alerts, isEmpty);
      expect(tracker.activeTracks.length, equals(1));
      expect(tracker.activeTracks.first.consecutiveFrames, equals(1));
    });

    test('3 consecutive confirming frames trigger confirmed alert', () {
      const d1 = VisionDetection(label: 'person', confidence: 0.8, zone: SpatialZone.center, boxArea: 0.10, bottomY: 0.70, timestamp: 1000);
      const d2 = VisionDetection(label: 'person', confidence: 0.82, zone: SpatialZone.center, boxArea: 0.12, bottomY: 0.72, timestamp: 1100);
      const d3 = VisionDetection(label: 'person', confidence: 0.85, zone: SpatialZone.center, boxArea: 0.14, bottomY: 0.75, timestamp: 1200);

      expect(tracker.processDetections([d1], nowMs: 1000), isEmpty);
      expect(tracker.processDetections([d2], nowMs: 1100), isEmpty);

      final confirmedAlerts = tracker.processDetections([d3], nowMs: 1200);
      expect(confirmedAlerts.length, equals(1));
      expect(confirmedAlerts.first.label, equals('person'));
      expect(confirmedAlerts.first.speechText, contains('person directly ahead'));
    });

    test('threat score is higher for center zone and bottom-edge proximity', () {
      final centerTrack = TrackedObstacle(
        trackId: 1,
        label: 'obstacle',
        smoothedArea: 0.20,
        smoothedBottomY: 0.85,
        areaGrowthRate: 0.05,
        zone: SpatialZone.center,
        confidence: 0.9,
        lastSeenTimestamp: 1000,
      );

      final sideTrack = TrackedObstacle(
        trackId: 2,
        label: 'obstacle',
        smoothedArea: 0.05,
        smoothedBottomY: 0.40,
        areaGrowthRate: 0.0,
        zone: SpatialZone.left,
        confidence: 0.9,
        lastSeenTimestamp: 1000,
      );

      expect(centerTrack.threatScore, greaterThan(sideTrack.threatScore));
    });

    test('stale tracks not seen for >800ms are automatically pruned', () {
      const d1 = VisionDetection(label: 'chair', confidence: 0.8, zone: SpatialZone.right, boxArea: 0.08, bottomY: 0.5, timestamp: 1000);
      tracker.processDetections([d1], nowMs: 1000);
      expect(tracker.activeTracks.length, equals(1));

      // 900ms later with no detection
      tracker.processDetections([], nowMs: 1900);
      expect(tracker.activeTracks, isEmpty);
    });
  });
}
