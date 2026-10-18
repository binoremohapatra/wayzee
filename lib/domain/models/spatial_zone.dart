/// Spatial zones relative to the user's forward heading.
/// Defined by horizontal field of view (HFOV):
/// - Left: bearing < -12 degrees
/// - Center: bearing between -12 and +12 degrees
/// - Right: bearing > +12 degrees
enum SpatialZone {
  left('left', 'on your left'),
  center('center', 'directly ahead'),
  right('right', 'on your right');

  final String id;
  final String speechLabel;

  const SpatialZone(this.id, this.speechLabel);

  /// Computes the spatial zone from a normalized bounding box horizontal center [centerX] (0.0 to 1.0)
  /// given the camera's horizontal field of view in degrees [hfovDegrees] (typically ~65 deg for mobile cameras).
  static SpatialZone fromNormalizedCenter(double centerX, {double hfovDegrees = 65.0}) {
    // Bearing angle from optical center: 0.5 is 0 degrees
    final bearingDeg = (centerX - 0.5) * hfovDegrees;
    if (bearingDeg < -12.0) {
      return SpatialZone.left;
    } else if (bearingDeg > 12.0) {
      return SpatialZone.right;
    } else {
      return SpatialZone.center;
    }
  }

  static SpatialZone fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'left':
        return SpatialZone.left;
      case 'right':
        return SpatialZone.right;
      case 'center':
      default:
        return SpatialZone.center;
    }
  }
}
