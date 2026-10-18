import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/fusion/fusion_engine.dart';
import 'package:wayze/domain/fusion/sensor_source.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';

void main() {
  group('FusionEngine Drop-Off & Proximity Rule Tests', () {
    late AlertQueue alertQueue;
    late VisionTracker tracker;
    late MockHapticService mockHaptics;
    late FusionEngine engine;

    setUp(() {
      alertQueue = AlertQueue();
      tracker = VisionTracker();
      mockHaptics = MockHapticService();
      engine = FusionEngine(
        alertQueue: alertQueue,
        visionTracker: tracker,
        hapticService: mockHaptics,
        expectedDownDistanceCm: 110.0,
        dropOffThresholdCm: 35.0, // > 145cm triggers drop-off
        frontObstacleThresholdCm: 50.0,
      );
    });

    test('single drop-off reading does not trigger alert (noise suppression)', () {
      final sample1 = SensorReading(
        timestamp: DateTime.now(),
        frontDistanceCm: 250.0,
        downDistanceCm: 220.0, // Drop-off detected
      );

      engine.ingestSensorReading(sample1);
      final alert = alertQueue.dequeue();
      expect(alert, isNull);
      expect(mockHaptics.triggerHistory, isEmpty);
    });

    test('>=2 consecutive drop-off readings trigger immediate P0 Stairs Down alert and danger haptics', () {
      final t1 = DateTime.now();
      final t2 = t1.add(const Duration(milliseconds: 100));

      final sample1 = SensorReading(timestamp: t1, frontDistanceCm: 250.0, downDistanceCm: 220.0);
      final sample2 = SensorReading(timestamp: t2, frontDistanceCm: 250.0, downDistanceCm: 225.0);

      engine.ingestSensorReading(sample1);
      engine.ingestSensorReading(sample2);

      final alert = alertQueue.dequeue();
      expect(alert, isNotNull);
      expect(alert!.priority, equals(AlertPriority.p0Danger));
      expect(alert.speechText, equals('Stairs down ahead. Stop.'));
      expect(mockHaptics.triggerHistory, contains(HapticPattern.danger));
    });

    test('>=2 consecutive front obstacle < 50cm trigger immediate P0 Stop alert', () {
      final t1 = DateTime.now();
      final t2 = t1.add(const Duration(milliseconds: 100));

      final sample1 = SensorReading(timestamp: t1, frontDistanceCm: 42.0, downDistanceCm: 110.0);
      final sample2 = SensorReading(timestamp: t2, frontDistanceCm: 38.0, downDistanceCm: 110.0);

      engine.ingestSensorReading(sample1);
      engine.ingestSensorReading(sample2);

      final alert = alertQueue.dequeue();
      expect(alert, isNotNull);
      expect(alert!.priority, equals(AlertPriority.p0Danger));
      expect(alert.speechText, equals('Obstacle directly ahead. Stop.'));
      expect(mockHaptics.triggerHistory, contains(HapticPattern.danger));
    });

    test('steady normal walking creates zero hazard alerts', () {
      final t = DateTime.now();
      for (int i = 0; i < 5; i++) {
        engine.ingestSensorReading(
          SensorReading(
            timestamp: t.add(Duration(milliseconds: i * 100)),
            frontDistanceCm: 250.0,
            downDistanceCm: 110.0,
          ),
        );
      }
      expect(alertQueue.dequeue(), isNull);
      expect(mockHaptics.triggerHistory, isEmpty);
    });
  });
}
