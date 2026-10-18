import 'package:flutter/foundation.dart';
// import 'package:onnxruntime/onnxruntime.dart' as ort; // TODO: Fix onnxruntime API
import 'dart:io';
import 'detector.dart';

class OnnxDetector extends Detector {
  // OrtSession? _session; // TODO: Fix onnxruntime API
  final String modelPath;
  final String labelsPath;
  final List<String> _labels;
  bool _isLoaded = false;

  OnnxDetector({
    required this.modelPath,
    required this.labelsPath,
  }) : _labels = [];

  static Future<OnnxDetector> create({
    required String modelPath,
    required String labelsPath,
  }) async {
    final detector = OnnxDetector(
      modelPath: modelPath,
      labelsPath: labelsPath,
    );
    await detector.loadModel();
    return detector;
  }

  @override
  Future<void> loadModel() async {
    try {
      // Check if model file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        debugPrint('OnnxDetector: Model file not found: $modelPath');
        return;
      }

      final bytes = await modelFile.readAsBytes();
      debugPrint('OnnxDetector: Loading model (${bytes.length} bytes)');

      // TODO: Fix onnxruntime API - incorrect usage
      // _session = OrtSession.fromBuffer(bytes, OrtSessionOptions());

      // Load labels
      final labelsFile = File(labelsPath);
      if (await labelsFile.exists()) {
        final labelsText = await labelsFile.readAsString();
        _labels.addAll(labelsText.split('\n').where((l) => l.isNotEmpty));
        debugPrint('OnnxDetector: Loaded ${_labels.length} labels');
      } else {
        debugPrint('OnnxDetector: Labels file not found: $labelsPath');
      }

      _isLoaded = true;
      debugPrint('OnnxDetector: Model loading skipped (API fix needed)');
    } catch (e) {
      debugPrint('OnnxDetector: Error loading model: $e');
      _isLoaded = false;
    }
  }

  @override
  Future<List<Detection>> detect(dynamic image) async {
    if (!_isLoaded) {
      debugPrint('OnnxDetector: Model not loaded');
      return [];
    }

    try {
      // TODO: Implement actual inference after fixing API
      debugPrint('OnnxDetector: Inference not yet implemented');
      return [];
    } catch (e) {
      debugPrint('OnnxDetector: Inference error: $e');
      return [];
    }
  }

  @override
  void close() {
    // _session?.release(); // TODO: Fix onnxruntime API
    _isLoaded = false;
  }
}
