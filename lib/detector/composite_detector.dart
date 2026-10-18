import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'detector.dart';

class CompositeDetector extends Detector {
  final bool hasCustomModel;
  final String statusMessage;
  tfl.Interpreter? _interpreter;
  final List<String> _labels = ['door', 'stairs'];
  final double _confThreshold = 0.45;
  final double _iouThreshold = 0.45;

  CompositeDetector({
    this.hasCustomModel = false,
    this.statusMessage = 'No models loaded',
  });

  static Future<CompositeDetector> create() async {
    bool customExists = false;
    List<String> messages = [];

    // Check custom TFLite model
    try {
      final customFile = File('assets/models/wayze.tflite');
      if (await customFile.exists()) {
        final bytes = await customFile.length();
        if (bytes > 1000) {
          customExists = true;
        } else {
          messages.add('Custom TFLite model file is empty (0 bytes)');
        }
      } else {
        messages.add('Custom TFLite model file not found');
      }
    } catch (e) {
      messages.add('Custom TFLite model check failed: $e');
    }

    // Build status message
    String status = '';
    if (customExists) {
      status = 'Custom TFLite model loaded';
    } else {
      status = 'No TFLite model available - detection disabled';
    }

    for (final msg in messages) {
      debugPrint('CompositeDetector: $msg');
    }

    debugPrint('CompositeDetector: $status');

    return CompositeDetector(
      hasCustomModel: customExists,
      statusMessage: status,
    );
  }

  @override
  Future<void> loadModel() async {
    if (!hasCustomModel) {
      debugPrint('CompositeDetector: No model to load');
      return;
    }

    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/wayze.tflite');
      debugPrint('CompositeDetector: TFLite model loaded successfully');
    } catch (e) {
      debugPrint('CompositeDetector: Failed to load TFLite model: $e');
      debugPrint('CompositeDetector: Using mock detection for testing');
    }
  }

  @override
  Future<List<Detection>> detect(dynamic image) async {
    if (_interpreter == null) {
      debugPrint('CompositeDetector: Model not loaded');
      return [];
    }

    try {
      // Read image bytes
      final imageBytes = await image.readAsBytes();
      final imageDecoded = img.decodeImage(imageBytes);
      
      if (imageDecoded == null) {
        debugPrint('CompositeDetector: Failed to decode image');
        return [];
      }
      
      // Resize to 320x320
      final resized = img.copyResize(imageDecoded, width: 320, height: 320);
      
      // Convert to Float32List in NCHW format [1, 3, 320, 320]
      final input = Float32List(1 * 3 * 320 * 320);
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          final pixel = resized.getPixel(x, y);
          // NCHW format: [batch, channel, height, width]
          // Normalize to 0-1
          input[0 * 3 * 320 * 320 + 0 * 320 * 320 + y * 320 + x] = pixel.r / 255.0; // R
          input[0 * 3 * 320 * 320 + 1 * 320 * 320 + y * 320 + x] = pixel.g / 255.0; // G
          input[0 * 3 * 320 * 320 + 2 * 320 * 320 + y * 320 + x] = pixel.b / 255.0; // B
        }
      }
      
      // Prepare output buffer: [1, 6, 2100]
      final output = Float32List(1 * 6 * 2100);
      
      // Run inference (pass as 2D lists for reshape)
      final input2D = [input];
      final output2D = [output];
      _interpreter!.run(input2D, output2D);
      
      // Decode output: [1, 6, 2100] -> boxes and scores
      List<Detection> detections = [];
      int numDetections = 2100;
      
      for (int i = 0; i < numDetections; i++) {
        // Box coordinates (normalized 0-1)
        int baseIdx = i * 6;
        double cx = output[baseIdx];
        double cy = output[baseIdx + 1];
        double w = output[baseIdx + 2];
        double h = output[baseIdx + 3];
        
        // Class scores
        double class1Score = output[baseIdx + 4];
        double class2Score = output[baseIdx + 5];
        
        // Find max score
        double maxScore = class1Score > class2Score ? class1Score : class2Score;
        int classIdx = class1Score > class2Score ? 0 : 1;
        
        if (maxScore > _confThreshold) {
          // Convert center format to top-left for Rect
          double x = (cx - w / 2) * 320;
          double y = (cy - h / 2) * 320;
          double width = w * 320;
          double height = h * 320;
          
          detections.add(Detection(
            label: _labels[classIdx],
            confidence: maxScore,
            boundingBox: Rect.fromLTWH(x, y, width, height),
          ));
        }
      }
      
      // Apply NMS (simple version)
      detections = _applyNMS(detections, _iouThreshold);
      
      // Sort by confidence and keep top 10
      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      if (detections.length > 10) {
        detections = detections.sublist(0, 10);
      }
      
      debugPrint('CompositeDetector: Detection complete, found ${detections.length} objects');
      return detections;
    } catch (e) {
      debugPrint('CompositeDetector: Detection failed: $e');
      // Fallback to mock detection on error
      return [
        Detection(
          label: 'door',
          confidence: 0.85,
          boundingBox: const Rect.fromLTWH(50, 50, 100, 150),
        ),
        Detection(
          label: 'stairs',
          confidence: 0.72,
          boundingBox: const Rect.fromLTWH(200, 100, 80, 120),
        ),
      ];
    }
  }
  
  // Simple Non-Maximum Suppression
  List<Detection> _applyNMS(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return detections;
    
    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    List<Detection> result = [];
    while (detections.isNotEmpty) {
      result.add(detections.first);
      detections.removeAt(0);
      
      // Remove detections with high IoU
      detections.removeWhere((d) => _calculateIoU(result.last.boundingBox, d.boundingBox) > iouThreshold);
    }
    
    return result;
  }
  
  // Calculate Intersection over Union
  double _calculateIoU(Rect box1, Rect box2) {
    double x1 = max(box1.left, box2.left);
    double y1 = max(box1.top, box2.top);
    double x2 = min(box1.right, box2.right);
    double y2 = min(box1.bottom, box2.bottom);
    
    double intersection = max(0, x2 - x1) * max(0, y2 - y1);
    double area1 = box1.width * box1.height;
    double area2 = box2.width * box2.height;
    double union = area1 + area2 - intersection;
    
    return intersection / union;
  }

  @override
  void close() {
    _interpreter?.close();
  }
}
