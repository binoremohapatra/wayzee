import 'dart:math' as math;
import '../../domain/models/spatial_zone.dart';

/// Single ground-truth bounding box annotation with optional file hash for data leakage checking.
class GroundTruthBox {
  final String fileId;
  final String fileHash;
  final String label;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final SpatialZone zone;

  const GroundTruthBox({
    required this.fileId,
    this.fileHash = '',
    required this.label,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.zone = SpatialZone.center,
  });

  double get area => math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
}

/// Single model prediction with confidence score and zone assignment.
class PredictionBox {
  final String fileId;
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final SpatialZone zone;

  const PredictionBox({
    required this.fileId,
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.zone = SpatialZone.center,
  });

  double get area => math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
}

/// Evaluation statistics for a specific class.
class ClassMetrics {
  final String label;
  final int groundTruthCount;
  final int predictionCount;
  final int tp;
  final int fp;
  final int fn;

  const ClassMetrics({
    required this.label,
    required this.groundTruthCount,
    required this.predictionCount,
    required this.tp,
    required this.fp,
    required this.fn,
  });

  double get precision => (tp + fp) > 0 ? tp / (tp + fp) : 0.0;
  double get recall => (tp + fn) > 0 ? tp / (tp + fn) : 0.0;
  double get f1 =>
      (precision + recall) > 0 ? 2 * (precision * recall) / (precision + recall) : 0.0;
}

/// Complete benchmark evaluation result across all classes, zones, and safety thresholds.
class EvaluationResult {
  final int totalGroundTruth;
  final int totalPredictions;
  final Map<String, ClassMetrics> perClassMetrics;
  final Map<String, Map<String, int>> confusionMatrix;
  final double zoneAccuracy;
  final double stairsRecall;
  final bool stairsRecallPassing;
  final bool hasTrainingOverlap;
  final List<String> overlappingFiles;

  const EvaluationResult({
    required this.totalGroundTruth,
    required this.totalPredictions,
    required this.perClassMetrics,
    required this.confusionMatrix,
    required this.zoneAccuracy,
    required this.stairsRecall,
    required this.stairsRecallPassing,
    required this.hasTrainingOverlap,
    required this.overlappingFiles,
  });

  /// Generates a comprehensive markdown report suitable for technical documentation and audit logs.
  String generateMarkdownReport() {
    final buf = StringBuffer();
    buf.writeln('# Wayze YOLOv8 INT8 Model Evaluation Report');
    buf.writeln('**Generated on:** ${DateTime.now().toIso8601String()}');
    buf.writeln();

    // 1. Data Contamination Alert
    if (hasTrainingOverlap) {
      buf.writeln('> [!CAUTION]');
      buf.writeln('> **DATA CONTAMINATION DETECTED!**');
      buf.writeln('> ${overlappingFiles.length} test sample(s) were found in the training manifest.');
      buf.writeln('> Overlapping items: ${overlappingFiles.take(5).join(", ")}${overlappingFiles.length > 5 ? " (and more...)" : ""}');
      buf.writeln('> Results MUST NOT be cited until test split is purged.');
      buf.writeln();
    } else {
      buf.writeln('> [!NOTE]');
      buf.writeln('> Zero data overlap detected between training manifest and test set. Evaluation split is clean.');
      buf.writeln();
    }

    // 2. Critical Safety: Stairs Recall Badge
    buf.writeln('## Critical Safety Metric: Stairs Recall');
    buf.writeln('- **Stairs Detection Recall:** ${(stairsRecall * 100).toStringAsFixed(1)}%');
    buf.writeln('- **Target Safety Threshold:** >= 95.0%');
    if (stairsRecallPassing) {
      buf.writeln('- **Status:** PASS (Meets safety benchmark for drop-off and stairs hazards)');
    } else {
      buf.writeln('- **Status:** FAIL (Hazard risk! Under 95% threshold; fall hazard hedge alert required)');
    }
    buf.writeln();

    // 3. Overall Summary Table
    buf.writeln('## Summary Statistics');
    buf.writeln('| Metric | Value |');
    buf.writeln('| :--- | :--- |');
    buf.writeln('| Total Ground Truth Annotations | $totalGroundTruth |');
    buf.writeln('| Total Detections Evaluated | $totalPredictions |');
    buf.writeln('| Spatial Zone Classification Accuracy | ${(zoneAccuracy * 100).toStringAsFixed(1)}% |');
    buf.writeln('| Overlap Audit Status | ${hasTrainingOverlap ? "CONTAMINATED" : "CLEAN"} |');
    buf.writeln();

    // 4. Per-Class Performance Breakdown
    buf.writeln('## Per-Class Precision, Recall & F1');
    buf.writeln('| Class | GT Count | Pred Count | TP | FP | FN | Precision | Recall | F1 Score |');
    buf.writeln('| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |');
    for (final entry in perClassMetrics.entries) {
      final m = entry.value;
      buf.writeln('| `${m.label}` | ${m.groundTruthCount} | ${m.predictionCount} | ${m.tp} | ${m.fp} | ${m.fn} | '
          '${(m.precision * 100).toStringAsFixed(1)}% | '
          '${(m.recall * 100).toStringAsFixed(1)}% | '
          '${(m.f1 * 100).toStringAsFixed(1)}% |');
    }
    buf.writeln();

    // 5. Confusion Matrix
    buf.writeln('## Confusion Matrix (True Class vs Predicted Class)');
    final classes = perClassMetrics.keys.toList();
    buf.write('| True \\ Pred |');
    for (final c in classes) {
      buf.write(' `$c` |');
    }
    buf.writeln(' `Background` |');
    buf.write('| :--- |');
    for (var i = 0; i <= classes.length; i++) {
      buf.write(' :---: |');
    }
    buf.writeln();

    for (final trueClass in classes) {
      buf.write('| `$trueClass` |');
      for (final predClass in classes) {
        final count = confusionMatrix[trueClass]?[predClass] ?? 0;
        buf.write(' $count |');
      }
      final bgCount = confusionMatrix[trueClass]?['Background'] ?? 0;
      buf.write(' $bgCount |');
      buf.writeln();
    }

    return buf.toString();
  }
}

/// Evaluator that ingests ground-truth boxes and predicted boxes, applies IoU matching,
/// verifies training data independence, and calculates per-class metrics.
class LabelledEvaluator {
  final double iouThreshold;
  final Set<String> trainingFileIds;
  final Set<String> trainingFileHashes;

  LabelledEvaluator({
    this.iouThreshold = 0.45,
    Set<String>? trainingFileIds,
    Set<String>? trainingFileHashes,
  })  : trainingFileIds = trainingFileIds ?? {},
        trainingFileHashes = trainingFileHashes ?? {};

  /// Computes intersection-over-union between two boxes
  double calculateIoU(
      double ax1, double ay1, double ax2, double ay2,
      double bx1, double by1, double bx2, double by2) {
    final ix1 = math.max(ax1, bx1);
    final iy1 = math.max(ay1, by1);
    final ix2 = math.min(ax2, bx2);
    final iy2 = math.min(ay2, by2);

    final iw = math.max(0.0, ix2 - ix1);
    final ih = math.max(0.0, iy2 - iy1);
    final interArea = iw * ih;

    final areaA = math.max(0.0, ax2 - ax1) * math.max(0.0, ay2 - ay1);
    final areaB = math.max(0.0, bx2 - bx1) * math.max(0.0, by2 - by1);

    final unionArea = areaA + areaB - interArea;
    return unionArea > 0 ? interArea / unionArea : 0.0;
  }

  /// Evaluates predictions against ground truth
  EvaluationResult evaluate({
    required List<GroundTruthBox> groundTruth,
    required List<PredictionBox> predictions,
  }) {
    // 1. Audit training data overlap
    final overlapping = <String>[];
    for (final gt in groundTruth) {
      if ((gt.fileId.isNotEmpty && trainingFileIds.contains(gt.fileId)) ||
          (gt.fileHash.isNotEmpty && trainingFileHashes.contains(gt.fileHash))) {
        if (!overlapping.contains(gt.fileId)) {
          overlapping.add(gt.fileId);
        }
      }
    }

    // Group by fileId
    final gtByFile = <String, List<GroundTruthBox>>{};
    for (final gt in groundTruth) {
      gtByFile.putIfAbsent(gt.fileId, () => []).add(gt);
    }

    final predByFile = <String, List<PredictionBox>>{};
    for (final pred in predictions) {
      predByFile.putIfAbsent(pred.fileId, () => []).add(pred);
    }

    // Collect all unique labels
    final allLabels = <String>{};
    for (final gt in groundTruth) {
      allLabels.add(gt.label);
    }
    for (final pred in predictions) {
      allLabels.add(pred.label);
    }

    final tpCounts = <String, int>{};
    final fpCounts = <String, int>{};
    final fnCounts = <String, int>{};
    final confusion = <String, Map<String, int>>{};

    for (final l in allLabels) {
      tpCounts[l] = 0;
      fpCounts[l] = 0;
      fnCounts[l] = 0;
      confusion[l] = {};
      for (final p in allLabels) {
        confusion[l]![p] = 0;
      }
      confusion[l]!['Background'] = 0;
    }

    int matchingZoneCount = 0;
    int totalTpCount = 0;

    // Evaluate on every file
    final allFiles = <String>{...gtByFile.keys, ...predByFile.keys};
    for (final file in allFiles) {
      final fileGts = gtByFile[file] ?? [];
      // Sort predictions by highest confidence first
      final filePreds = (predByFile[file] ?? []).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));

      final matchedGtIndices = <int>{};

      for (final pred in filePreds) {
        int bestGtIdx = -1;
        double bestIoU = 0.0;

        for (var i = 0; i < fileGts.length; i++) {
          if (matchedGtIndices.contains(i)) continue;
          final gt = fileGts[i];

          final iou = calculateIoU(
            pred.x1, pred.y1, pred.x2, pred.y2,
            gt.x1, gt.y1, gt.x2, gt.y2,
          );

          if (iou >= iouThreshold && iou > bestIoU) {
            bestIoU = iou;
            bestGtIdx = i;
          }
        }

        if (bestGtIdx >= 0) {
          final matchedGt = fileGts[bestGtIdx];
          matchedGtIndices.add(bestGtIdx);

          if (matchedGt.label == pred.label) {
            // True Positive
            tpCounts[pred.label] = (tpCounts[pred.label] ?? 0) + 1;
            totalTpCount++;
            if (matchedGt.zone == pred.zone) {
              matchingZoneCount++;
            }
            confusion[matchedGt.label]![pred.label] =
                (confusion[matchedGt.label]![pred.label] ?? 0) + 1;
          } else {
            // Misclassification: False Positive for pred.label, confusion from matchedGt.label
            fpCounts[pred.label] = (fpCounts[pred.label] ?? 0) + 1;
            confusion[matchedGt.label]![pred.label] =
                (confusion[matchedGt.label]![pred.label] ?? 0) + 1;
          }
        } else {
          // False positive with no GT match (Hallucination)
          fpCounts[pred.label] = (fpCounts[pred.label] ?? 0) + 1;
        }
      }

      // Any unmatched GT box is a False Negative
      for (var i = 0; i < fileGts.length; i++) {
        if (!matchedGtIndices.contains(i)) {
          final gt = fileGts[i];
          fnCounts[gt.label] = (fnCounts[gt.label] ?? 0) + 1;
          confusion[gt.label]!['Background'] =
              (confusion[gt.label]!['Background'] ?? 0) + 1;
        }
      }
    }

    // Build per-class metrics
    final perClass = <String, ClassMetrics>{};
    for (final label in allLabels) {
      final gtCount = groundTruth.where((g) => g.label == label).length;
      final predCount = predictions.where((p) => p.label == label).length;
      perClass[label] = ClassMetrics(
        label: label,
        groundTruthCount: gtCount,
        predictionCount: predCount,
        tp: tpCounts[label] ?? 0,
        fp: fpCounts[label] ?? 0,
        fn: fnCounts[label] ?? 0,
      );
    }

    // Calculate stairs recall specifically
    final stairsLabels = {'stairs', 'stairs_up', 'stairs_down'};
    int totalStairsGt = 0;
    int totalStairsTp = 0;
    for (final l in stairsLabels) {
      if (perClass.containsKey(l)) {
        totalStairsGt += (perClass[l]!.tp + perClass[l]!.fn);
        totalStairsTp += perClass[l]!.tp;
      }
    }

    final stairsRecall = totalStairsGt > 0 ? totalStairsTp / totalStairsGt : 1.0;
    final stairsRecallPassing = stairsRecall >= 0.95;

    final zoneAccuracy = totalTpCount > 0 ? matchingZoneCount / totalTpCount : 1.0;

    return EvaluationResult(
      totalGroundTruth: groundTruth.length,
      totalPredictions: predictions.length,
      perClassMetrics: perClass,
      confusionMatrix: confusion,
      zoneAccuracy: zoneAccuracy,
      stairsRecall: stairsRecall,
      stairsRecallPassing: stairsRecallPassing,
      hasTrainingOverlap: overlapping.isNotEmpty,
      overlappingFiles: overlapping,
    );
  }

  /// Parses CSV format: fileId,label,x1,y1,x2,y2,zone,hash
  static List<GroundTruthBox> parseGroundTruthCsv(String csvContent) {
    final lines = csvContent.split('\n');
    final results = <GroundTruthBox>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length >= 6) {
        final zoneStr = parts.length > 6 ? parts[6].trim().toLowerCase() : 'center';
        final zone = zoneStr == 'left'
            ? SpatialZone.left
            : (zoneStr == 'right' ? SpatialZone.right : SpatialZone.center);
        final hash = parts.length > 7 ? parts[7].trim() : '';

        results.add(GroundTruthBox(
          fileId: parts[0].trim(),
          label: parts[1].trim(),
          x1: double.tryParse(parts[2].trim()) ?? 0.0,
          y1: double.tryParse(parts[3].trim()) ?? 0.0,
          x2: double.tryParse(parts[4].trim()) ?? 0.0,
          y2: double.tryParse(parts[5].trim()) ?? 0.0,
          zone: zone,
          fileHash: hash,
        ));
      }
    }
    return results;
  }

  /// Parses predictions CSV: fileId,label,confidence,x1,y1,x2,y2,zone
  static List<PredictionBox> parsePredictionsCsv(String csvContent) {
    final lines = csvContent.split('\n');
    final results = <PredictionBox>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length >= 7) {
        final zoneStr = parts.length > 7 ? parts[7].trim().toLowerCase() : 'center';
        final zone = zoneStr == 'left'
            ? SpatialZone.left
            : (zoneStr == 'right' ? SpatialZone.right : SpatialZone.center);

        results.add(PredictionBox(
          fileId: parts[0].trim(),
          label: parts[1].trim(),
          confidence: double.tryParse(parts[2].trim()) ?? 0.0,
          x1: double.tryParse(parts[3].trim()) ?? 0.0,
          y1: double.tryParse(parts[4].trim()) ?? 0.0,
          x2: double.tryParse(parts[5].trim()) ?? 0.0,
          y2: double.tryParse(parts[6].trim()) ?? 0.0,
          zone: zone,
        ));
      }
    }
    return results;
  }
}
