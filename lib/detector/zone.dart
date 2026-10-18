enum Zone {
  left,
  centre,
  right,
}

extension ZoneExtension on Zone {
  String get label {
    switch (this) {
      case Zone.left:
        return 'left';
      case Zone.centre:
        return 'ahead';
      case Zone.right:
        return 'right';
    }
  }
}

class ZoneDetector {
  static Zone fromNormalizedX(double normalizedX) {
    // normalizedX is in range [0, 1] from left to right of image
    if (normalizedX < 0.33) {
      return Zone.left;
    } else if (normalizedX > 0.67) {
      return Zone.right;
    } else {
      return Zone.centre;
    }
  }

  static Zone fromBoundingBoxCenter(double centerX, double imageWidth) {
    final normalizedX = centerX / imageWidth;
    return fromNormalizedX(normalizedX);
  }
}
