import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/fusion/fusion_engine.dart';
import 'package:wayze/domain/fusion/replay_harness.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';

void main() {
  group('ReplayHarness Automated Telemetry Playback Tests', () {
    late AlertQueue alertQueue;
    late FusionEngine fusionEngine;
    late ReplayHarness harness;

    setUp(() {
      alertQueue = AlertQueue();
      fusionEngine = FusionEngine(
        alertQueue: alertQueue,
        visionTracker: VisionTracker(),
        hapticService: MockHapticService(),
      );
      harness = ReplayHarness(
        fusionEngine: fusionEngine,
        alertQueue: alertQueue,
      );
    });

    test('replays CSV log and triggers drop-off and obstacle alerts deterministically', () {
      final csvLog = [
        // Normal walking
        '1000, 250.0, 110.0, 0.8',
        '1100, 240.0, 110.0, 0.8',
        // Stairs drop-off starts (down distance jumps to 220cm)
        '1200, 230.0, 220.0, 0.8',
        '1300, 220.0, 225.0, 0.8',
        // User stops / recovers
        '1400, 200.0, 110.0, 0.1',
        // Obstacle approaches < 50cm
        '1500, 42.0, 110.0, 0.5',
        '1600, 35.0, 110.0, 0.5',
      ];

      final rows = csvLog.map((line) => ReplayLogRow.fromCsv(line)).toList();
      harness.replayLog(rows);

      // Verify emitted alerts during replay
      final alertTexts = harness.dequeuedAlerts.map((a) => a.speechText).toList();

      expect(alertTexts, contains('Stairs down ahead. Stop.'));
      expect(alertTexts, contains('Obstacle directly ahead. Stop.'));

      // Both must be P0 Danger
      final p0Alerts = harness.dequeuedAlerts.where((a) => a.priority == AlertPriority.p0Danger).toList();
      expect(p0Alerts.length, greaterThanOrEqualTo(2));
    });

    test('all-clear CSV log triggers zero false alarms', () {
      final clearCsvLog = [
        '1000, 300.0, 110.0, 0.7',
        '1100, 290.0, 110.0, 0.7',
        '1200, 280.0, 110.0, 0.7',
        '1300, 270.0, 110.0, 0.7',
        '1400, 260.0, 110.0, 0.7',
      ];

      final rows = clearCsvLog.map((line) => ReplayLogRow.fromCsv(line)).toList();
      harness.replayLog(rows);

      expect(harness.dequeuedAlerts, isEmpty);
    });
  });
}
