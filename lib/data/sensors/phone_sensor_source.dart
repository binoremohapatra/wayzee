import 'dart:async';
import 'dart:math';
import '../../domain/fusion/sensor_source.dart';

/// Sensor source for phone-only operation without external hardware.
/// Synthesizes ground distance based on pitch angle geometry and nominal hand height.
class PhoneSensorSource implements SensorSource {
  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  Timer? _ticker;

  final double nominalHoldingHeightCm;
  double _currentPitch = 45.0; // Typical 45 degree forward-downward phone grip

  PhoneSensorSource({this.nominalHoldingHeightCm = 110.0});

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  @override
  Future<void> start() async {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Nominal downward ground distance = height / sin(pitch)
      final rad = max(0.2, _currentPitch * pi / 180.0);
      final estimatedDownDistance = nominalHoldingHeightCm / sin(rad);

      final reading = SensorReading(
        timestamp: DateTime.now(),
        frontDistanceCm: 300.0, // Optical baseline
        downDistanceCm: estimatedDownDistance,
        pitchAngleDeg: _currentPitch,
        rollAngleDeg: 0.0,
        accelerationMps2: 0.05,
        isCaneConnected: false,
      );

      if (!_controller.isClosed) {
        _controller.add(reading);
      }
    });
  }

  void updatePitch(double pitchDeg) {
    _currentPitch = pitchDeg.clamp(10.0, 85.0);
  }

  @override
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    stop();
    _controller.close();
  }
}
