import '../alerts/alert_queue.dart';
import '../models/alert_item.dart';
import '../models/spatial_zone.dart';
import 'fusion_engine.dart';
import 'sensor_source.dart';
import '../../data/vision/native_vision_bridge.dart';

class ReplayLogRow {
  final int timestampMs;
  final double frontDistanceCm;
  final double downDistanceCm;
  final double accelMps2;
  final String? visionLabel;
  final double? visionConfidence;
  final SpatialZone? visionZone;
  final double? visionBoxArea;
  final double? visionBottomY;

  const ReplayLogRow({
    required this.timestampMs,
    required this.frontDistanceCm,
    required this.downDistanceCm,
    this.accelMps2 = 0.8,
    this.visionLabel,
    this.visionConfidence,
    this.visionZone,
    this.visionBoxArea,
    this.visionBottomY,
  });

  factory ReplayLogRow.fromCsv(String csvLine) {
    final parts = csvLine.split(',').map((s) => s.trim()).toList();
    final ts = int.parse(parts[0]);
    final front = double.parse(parts[1]);
    final down = double.parse(parts[2]);
    final accel = parts.length > 3 && parts[3].isNotEmpty ? double.parse(parts[3]) : 0.8;

    String? label;
    double? conf;
    SpatialZone? zone;
    double? area;
    double? bottomY;

    if (parts.length > 4 && parts[4].isNotEmpty) {
      label = parts[4];
      conf = double.tryParse(parts[5]);
      final zStr = parts[6].toLowerCase();
      zone = zStr == 'left' ? SpatialZone.left : (zStr == 'right' ? SpatialZone.right : SpatialZone.center);
      area = double.tryParse(parts[7]);
      bottomY = double.tryParse(parts[8]);
    }

    return ReplayLogRow(
      timestampMs: ts,
      frontDistanceCm: front,
      downDistanceCm: down,
      accelMps2: accel,
      visionLabel: label,
      visionConfidence: conf,
      visionZone: zone,
      visionBoxArea: area,
      visionBottomY: bottomY,
    );
  }
}

/// Deterministic replay harness for testing sensor and vision fusion against CSV/video logs.
class ReplayHarness {
  final FusionEngine fusionEngine;
  final AlertQueue alertQueue;
  final List<AlertItem> dispatchedP0Alerts = [];
  final List<AlertItem> dequeuedAlerts = [];

  ReplayHarness({
    required this.fusionEngine,
    required this.alertQueue,
  });

  /// Feeds a list of log rows sequentially into the fusion pipeline
  void replayLog(List<ReplayLogRow> rows) {
    dispatchedP0Alerts.clear();
    dequeuedAlerts.clear();
    fusionEngine.reset();
    alertQueue.clear();

    for (final row in rows) {
      final currentTime = DateTime.fromMillisecondsSinceEpoch(row.timestampMs);

      // Ingest sensor telemetry
      fusionEngine.ingestSensorReading(
        SensorReading(
          timestamp: currentTime,
          frontDistanceCm: row.frontDistanceCm,
          downDistanceCm: row.downDistanceCm,
          accelerationMps2: row.accelMps2,
          isCaneConnected: true,
        ),
      );

      // Ingest vision detection if present
      if (row.visionLabel != null && row.visionConfidence != null) {
        final detection = VisionDetection(
          label: row.visionLabel!,
          confidence: row.visionConfidence!,
          zone: row.visionZone ?? SpatialZone.center,
          boxArea: row.visionBoxArea ?? 0.1,
          bottomY: row.visionBottomY ?? 0.5,
          timestamp: row.timestampMs,
        );

        fusionEngine.ingestVisionDetections([detection], now: currentTime);
      }

      // Check dequeued alert
      final alert = alertQueue.dequeue(now: currentTime, isSystemIdle: true);
      if (alert != null) {
        dequeuedAlerts.add(alert);
      }
    }
  }
}
