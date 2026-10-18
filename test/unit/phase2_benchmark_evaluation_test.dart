import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/domain/benchmark/device_info_service.dart';
import 'package:wayze/domain/benchmark/benchmark_engine.dart';
import 'package:wayze/ml/evaluation/labelled_evaluator.dart';
import 'package:wayze/domain/models/spatial_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Device Hardware & Pitch Validity Auditing', () {
    test('Release build on real hardware passes pitch validity check', () {
      final info = DeviceInfo(
        model: 'Xiaomi Redmi Note 11',
        osVersion: 'Android 12 (API 31)',
        ramTotalBytes: 4 * 1024 * 1024 * 1024,
        soc: 'Snapdragon 680',
        isDebug: false,
        isEmulator: false,
      );

      expect(info.isValidForPitch, isTrue);
      expect(info.pitchWarningReason, isNull);
      expect(info.formattedRam, equals('4.0 GB'));
    });

    test('Emulator run is explicitly flagged as NOT VALID FOR PITCH', () {
      final info = DeviceInfo(
        model: 'sdk_gphone64_x86_64',
        osVersion: 'Android 14 (API 34)',
        ramTotalBytes: 3 * 1024 * 1024 * 1024,
        soc: 'goldfish',
        isDebug: true,
        isEmulator: true,
      );

      expect(info.isValidForPitch, isFalse);
      expect(info.pitchWarningReason, contains('NOT VALID FOR PITCH'));
    });

    test('Debug build on real phone is flagged for JIT skew', () {
      final info = DeviceInfo(
        model: 'Samsung Galaxy A13',
        osVersion: 'Android 13',
        ramTotalBytes: 4294967296,
        soc: 'Exynos 850',
        isDebug: true,
        isEmulator: false,
      );

      expect(info.isValidForPitch, isFalse);
      expect(info.pitchWarningReason, contains('DEBUG BUILD ACTIVE'));
    });
  });

  group('Phase 2: 5-Minute Timed Benchmark Session', () {
    test('Tracks p50, p95, max latency, average FPS and Delta FPS drop', () {
      final session = BenchmarkSession(targetDuration: const Duration(seconds: 15));
      session.start();

      // Simulate early baseline frames at high FPS (15 FPS, ~40ms inference)
      for (var i = 0; i < 5; i++) {
        session.recordFrame(
          preprocessingMs: 12,
          inferenceMs: 40 + (i * 2), // 40, 42, 44, 46, 48
          fps: 15.0,
          batteryPct: 90,
          thermalStatus: 'Nominal',
          delegate: 'CPU (XNNPACK)',
          inputSize: 320,
          detectionCount: 1,
        );
      }

      // Simulate subsequent frames experiencing thermal throttling (8 FPS, ~80ms inference)
      for (var i = 0; i < 5; i++) {
        session.recordFrame(
          preprocessingMs: 18,
          inferenceMs: 80 + (i * 4), // 80, 84, 88, 92, 96
          fps: 8.0,
          batteryPct: 88,
          thermalStatus: 'Moderate',
          delegate: 'CPU (XNNPACK)',
          inputSize: 320,
          detectionCount: 1,
        );
      }

      expect(session.totalFrames, equals(10));
      expect(session.p50InferenceMs, equals(80)); // Median of sorted 10 items
      expect(session.p95InferenceMs, equals(96)); // 95th percentile
      expect(session.maxInferenceMs, equals(96));
      expect(session.p50PreprocessingMs, equals(18));

      // Initial baseline FPS is 15.0, current FPS is 8.0 -> Delta FPS drop is 7.0
      expect(session.initialFps, closeTo(15.0, 0.1));
      expect(session.currentFps, closeTo(8.0, 0.1));
      expect(session.deltaFps, closeTo(7.0, 0.1));
      expect(session.percentageFpsDrop, closeTo(46.6, 1.0));

      final csv = session.exportCsv();
      expect(csv, contains('timestamp_epoch_ms,frame_idx,prep_ms,inference_ms'));
      expect(csv, contains('CPU (XNNPACK)'));
    });
  });

  group('Phase 2: Empty-Room False-Alarm Test Harness', () {
    test('Passes when extrapolated 30-min alarms are within threshold (<= 2)', () {
      final harness = FalseAlarmTestSession(
        testDuration: const Duration(minutes: 5),
        maxAllowedAlarmsPer30Min: 2,
      );
      harness.start();

      // Zero false alarms detected
      expect(harness.totalFalseAlarms, equals(0));
      expect(harness.extrapolated30MinAlarms, equals(0));
      expect(harness.isPassed, isTrue);

      final report = harness.exportSummary();
      expect(report, contains('Result: PASS'));
      expect(report, contains('Zero false alarms detected'));
    });

    test('Extrapolates 5-minute test counts to 30 minutes (count * 6)', () {
      final harness = FalseAlarmTestSession(
        testDuration: const Duration(minutes: 5),
        maxAllowedAlarmsPer30Min: 2,
      );
      harness.start();

      // 1 false alarm for 'chair' in 5 minutes
      harness.recordAlarm('chair');

      expect(harness.totalFalseAlarms, equals(1));
      // 1 * 6 = 6 alarms per 30 minutes -> Exceeds allowed max of 2!
      expect(harness.extrapolated30MinAlarms, equals(6));
      expect(harness.isPassed, isFalse);

      final report = harness.exportSummary();
      expect(report, contains('Result: FAIL'));
      expect(report, contains('chair: 1 alarms'));
    });
  });

  group('Phase 2: Labelled-Clip Evaluation Tool & Data Leakage Audit', () {
    test('Calculates Precision, Recall, F1, Zone Accuracy and Highlights Stairs Recall', () {
      final evaluator = LabelledEvaluator(iouThreshold: 0.40);

      final groundTruth = [
        const GroundTruthBox(
          fileId: 'frame_001.jpg',
          label: 'stairs_down',
          x1: 0.20, y1: 0.30, x2: 0.80, y2: 0.90,
          zone: SpatialZone.center,
        ),
        const GroundTruthBox(
          fileId: 'frame_002.jpg',
          label: 'door',
          x1: 0.40, y1: 0.10, x2: 0.70, y2: 0.80,
          zone: SpatialZone.center,
        ),
        const GroundTruthBox(
          fileId: 'frame_003.jpg',
          label: 'obstacle',
          x1: 0.10, y1: 0.50, x2: 0.35, y2: 0.85,
          zone: SpatialZone.left,
        ),
      ];

      final predictions = [
        // True Positive: stairs_down with high overlap and matching zone
        const PredictionBox(
          fileId: 'frame_001.jpg',
          label: 'stairs_down',
          confidence: 0.85,
          x1: 0.22, y1: 0.31, x2: 0.78, y2: 0.89,
          zone: SpatialZone.center,
        ),
        // True Positive: door with matching zone
        const PredictionBox(
          fileId: 'frame_002.jpg',
          label: 'door',
          confidence: 0.78,
          x1: 0.39, y1: 0.12, x2: 0.69, y2: 0.81,
          zone: SpatialZone.center,
        ),
        // False Positive hallucination
        const PredictionBox(
          fileId: 'frame_004.jpg',
          label: 'person',
          confidence: 0.62,
          x1: 0.50, y1: 0.20, x2: 0.80, y2: 0.90,
          zone: SpatialZone.right,
        ),
      ];

      final result = evaluator.evaluate(
        groundTruth: groundTruth,
        predictions: predictions,
      );

      expect(result.totalGroundTruth, equals(3));
      expect(result.totalPredictions, equals(3));

      // stairs_down had 1 GT, 1 matched Pred -> Recall = 1.0 (100%), Precision = 1.0 (100%)
      expect(result.stairsRecall, equals(1.0));
      expect(result.stairsRecallPassing, isTrue);

      // obstacle was not detected in frame_003 -> FN = 1
      expect(result.perClassMetrics['obstacle']!.fn, equals(1));
      expect(result.perClassMetrics['obstacle']!.recall, equals(0.0));

      // person was hallucinated in frame_004 -> FP = 1
      expect(result.perClassMetrics['person']!.fp, equals(1));
      expect(result.perClassMetrics['person']!.precision, equals(0.0));

      // Zone accuracy for matching true positive pairs
      expect(result.zoneAccuracy, equals(1.0));

      // Markdown report generated with tables
      final markdown = result.generateMarkdownReport();
      expect(markdown, contains('# Wayze YOLOv8 INT8 Model Evaluation Report'));
      expect(markdown, contains('Critical Safety Metric: Stairs Recall'));
      expect(markdown, contains('PASS (Meets safety benchmark'));
      expect(markdown, contains('`stairs_down`'));
    });

    test('Detects and warns on training set contamination / leakage', () {
      final evaluator = LabelledEvaluator(
        trainingFileIds: {'training_img_42.jpg', 'training_img_99.jpg'},
        trainingFileHashes: {'hash_deadbeef1234'},
      );

      final groundTruth = [
        const GroundTruthBox(
          fileId: 'training_img_42.jpg', // Contaminated!
          label: 'door',
          x1: 0.1, y1: 0.1, x2: 0.5, y2: 0.5,
        ),
        const GroundTruthBox(
          fileId: 'clean_test_01.jpg',
          fileHash: 'hash_deadbeef1234', // Contaminated by hash!
          label: 'stairs_up',
          x1: 0.2, y1: 0.2, x2: 0.8, y2: 0.8,
        ),
      ];

      final result = evaluator.evaluate(
        groundTruth: groundTruth,
        predictions: [],
      );

      expect(result.hasTrainingOverlap, isTrue);
      expect(result.overlappingFiles, contains('training_img_42.jpg'));
      expect(result.overlappingFiles, contains('clean_test_01.jpg'));

      final report = result.generateMarkdownReport();
      expect(report, contains('DATA CONTAMINATION DETECTED!'));
      expect(report, contains('MUST NOT be cited until test split is purged'));
    });

    test('Parses CSV input files for evaluation', () {
      const gtCsv = '''
fileId,label,x1,y1,x2,y2,zone,hash
test_1.png,stairs_down,0.1,0.2,0.8,0.9,center,abc123
test_2.png,door,0.3,0.1,0.7,0.8,left,def456
''';

      const predCsv = '''
fileId,label,confidence,x1,y1,x2,y2,zone
test_1.png,stairs_down,0.82,0.11,0.21,0.79,0.89,center
test_2.png,door,0.75,0.29,0.11,0.71,0.81,left
''';

      final gts = LabelledEvaluator.parseGroundTruthCsv(gtCsv);
      final preds = LabelledEvaluator.parsePredictionsCsv(predCsv);

      expect(gts.length, equals(2));
      expect(gts.first.label, equals('stairs_down'));
      expect(gts.first.zone, equals(SpatialZone.center));
      expect(gts.first.fileHash, equals('abc123'));

      expect(preds.length, equals(2));
      expect(preds.first.label, equals('stairs_down'));
      expect(preds.first.confidence, equals(0.82));

      final evaluator = LabelledEvaluator();
      final eval = evaluator.evaluate(groundTruth: gts, predictions: preds);

      expect(eval.stairsRecall, equals(1.0));
      expect(eval.stairsRecallPassing, isTrue);
      expect(eval.hasTrainingOverlap, isFalse);
    });
  });
}
