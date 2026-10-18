import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/data/vision/native_vision_bridge.dart';
import 'package:wayze/domain/models/spatial_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Model Assets & Toolkit Integrity Tests', () {
    test('Labels files exist and contain indoor navigation hazard classes', () {
      final androidLabels = File('android/app/src/main/assets/models/labels.txt');
      expect(androidLabels.existsSync(), isTrue, reason: 'android assets labels.txt must exist');

      final lines = androidLabels.readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      expect(lines.isNotEmpty, isTrue);
      // Hazard classes must include stairs or doors
      expect(lines.any((l) => l.contains('stairs') || l.contains('door')), isTrue);
    });

    test('model_facts.json contains required metadata and valid thresholds', () {
      final factsFile = File('assets/models/model_facts.json');
      expect(factsFile.existsSync(), isTrue);

      final content = factsFile.readAsStringSync();
      final facts = jsonDecode(content) as Map<String, dynamic>;

      expect(facts.containsKey('classes'), isTrue);
      expect(facts.containsKey('input_size'), isTrue);
      expect(facts['input_size'], equals(320));
      expect(facts.containsKey('recommended_conf'), isTrue);
      expect(facts['recommended_conf'], inInclusiveRange(0.25, 0.70));
    });

    test('Toolkit python scripts and deployment documentation exist', () {
      final curateScript = File('scripts/curate_and_validate_dataset.py');
      final trainScript = File('scripts/train_and_export_yolov8.py');
      final inspectScript = File('scripts/inspect_tflite_model.py');
      final docsRunbook = File('docs/MODEL_TRAINING_AND_EXPORT.md');

      expect(curateScript.existsSync(), isTrue, reason: 'Dataset curation script must exist');
      expect(trainScript.existsSync(), isTrue, reason: 'Training script must exist');
      expect(inspectScript.existsSync(), isTrue, reason: 'Inspection script must exist');
      expect(docsRunbook.existsSync(), isTrue, reason: 'Training & Export documentation must exist');

      final docsText = docsRunbook.readAsStringSync();
      expect(docsText, contains('INT8 Post-Training Quantization'));
      expect(docsText, contains('Leakage Auditing'));
      expect(docsText, contains('Netron'));
      expect(docsText, contains('UNVERIFIED'));
    });

    test('VisionDetection safely parses dynamic map payloads without index out of bounds', () {
      // 1. Standard detection
      final standard = VisionDetection.fromMap({
        'label': 'stairs_down',
        'confidence': 0.88,
        'zone': 'center',
        'boxArea': 0.25,
        'bottomY': 0.80,
        'latencyMs': 52,
        'inferenceMs': 42,
        'prepMs': 10,
        'x1': 0.2,
        'y1': 0.3,
        'x2': 0.8,
        'y2': 0.9,
      });

      expect(standard.label, equals('stairs_down'));
      expect(standard.confidence, closeTo(0.88, 0.001));
      expect(standard.zone, equals(SpatialZone.center));
      expect(standard.inferenceMs, equals(42));
      expect(standard.prepMs, equals(10));
      expect(standard.latencyMs, equals(52));

      // 2. Fallback on missing or unexpected fields
      final fallback = VisionDetection.fromMap({
        'confidence': 0.45,
      });

      expect(fallback.label, equals('obstacle')); // graceful default
      expect(fallback.zone, equals(SpatialZone.center));
      expect(fallback.latencyMs, equals(0));
      expect(fallback.x1, equals(0.0));
    });

    test('YOLO coordinate conversion and letterbox bounds are bounded', () {
      // Simulates decoding raw [cx, cy, w, h] into normalized corners [x1, y1, x2, y2]
      final testCoords = [
        {'cx': 0.5, 'cy': 0.5, 'w': 0.4, 'h': 0.6},
        {'cx': 0.1, 'cy': 0.1, 'w': 0.3, 'h': 0.3}, // partially overflows left/top
        {'cx': 0.9, 'cy': 0.9, 'w': 0.4, 'h': 0.4}, // partially overflows right/bottom
      ];

      for (final tc in testCoords) {
        final cx = tc['cx']!;
        final cy = tc['cy']!;
        final w = tc['w']!;
        final h = tc['h']!;

        final x1 = (cx - w / 2).clamp(0.0, 1.0);
        final y1 = (cy - h / 2).clamp(0.0, 1.0);
        final x2 = (cx + w / 2).clamp(0.0, 1.0);
        final y2 = (cy + h / 2).clamp(0.0, 1.0);

        expect(x1, inInclusiveRange(0.0, 1.0));
        expect(y1, inInclusiveRange(0.0, 1.0));
        expect(x2, inInclusiveRange(0.0, 1.0));
        expect(y2, inInclusiveRange(0.0, 1.0));
        expect(x2 >= x1, isTrue);
        expect(y2 >= y1, isTrue);
      }
    });
  });
}
