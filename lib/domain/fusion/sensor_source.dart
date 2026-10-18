import 'dart:async';

/// Telemetry reading from smart cane or phone-mounted sensors.
class SensorReading {
  final DateTime timestamp;
  final double frontDistanceCm;
  final double downDistanceCm;
  final double pitchAngleDeg;
  final double rollAngleDeg;
  final double accelerationMps2;
  final bool isCaneConnected;

  const SensorReading({
    required this.timestamp,
    required this.frontDistanceCm,
    required this.downDistanceCm,
    this.pitchAngleDeg = 0.0,
    this.rollAngleDeg = 0.0,
    this.accelerationMps2 = 0.0,
    this.isCaneConnected = false,
  });

  /// True if reading suggests cane or phone is stationary (e.g. user waiting).
  bool get isStationary => accelerationMps2.abs() < 0.25;
}

/// Abstract stream-based sensor source.
/// Business logic depends strictly on this contract, allowing seamless swap
/// from PhoneSensorSource to MockCaneSource to BleCaneSource.
abstract class SensorSource {
  Stream<SensorReading> get readingStream;
  Future<void> start();
  Future<void> stop();
  void dispose();
}
