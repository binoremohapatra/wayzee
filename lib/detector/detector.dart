import 'dart:ui';

abstract class Detector {
  Future<void> loadModel();
  Future<List<Detection>> detect(dynamic image);
  void close();
}

class Detection {
  final String label;
  final double confidence;
  final Rect boundingBox;

  Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}
