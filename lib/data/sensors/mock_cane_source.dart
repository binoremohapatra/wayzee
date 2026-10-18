import 'dart:async';
import '../../domain/fusion/sensor_source.dart';

enum CaneScenario {
  normalWalking,
  stairsDownAhead,
  obstacleClose,
  stationary,
}

/// Mock smart cane sensor source for test benches, UI sliders, and automated replay.
class MockCaneSource implements SensorSource {
  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  Timer? _ticker;

  double currentFrontDistanceCm;
  double currentDownDistanceCm;
  double currentAcceleration;
  bool isConnected;

  MockCaneSource({
    this.currentFrontDistanceCm = 250.0,
    this.currentDownDistanceCm = 110.0,
    this.currentAcceleration = 0.8,
    this.isConnected = true,
  });

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  @override
  Future<void> start() async {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      emitCurrent();
    });
  }

  void emitCurrent() {
    if (_controller.isClosed) return;
    _controller.add(
      SensorReading(
        timestamp: DateTime.now(),
        frontDistanceCm: currentFrontDistanceCm,
        downDistanceCm: currentDownDistanceCm,
        pitchAngleDeg: 45.0,
        rollAngleDeg: 0.0,
        accelerationMps2: currentAcceleration,
        isCaneConnected: isConnected,
      ),
    );
  }

  /// Sets scripted test scenario
  void loadScenario(CaneScenario scenario) {
    switch (scenario) {
      case CaneScenario.normalWalking:
        currentFrontDistanceCm = 250.0;
        currentDownDistanceCm = 110.0;
        currentAcceleration = 0.8;
        break;
      case CaneScenario.stairsDownAhead:
        currentFrontDistanceCm = 200.0;
        // Significant down-range increase triggers drop-off rule
        currentDownDistanceCm = 220.0;
        currentAcceleration = 0.6;
        break;
      case CaneScenario.obstacleClose:
        // Barrier closer than 50cm triggers P0 obstacle rule
        currentFrontDistanceCm = 38.0;
        currentDownDistanceCm = 110.0;
        currentAcceleration = 0.7;
        break;
      case CaneScenario.stationary:
        currentFrontDistanceCm = 250.0;
        currentDownDistanceCm = 110.0;
        currentAcceleration = 0.05;
        break;
    }
    emitCurrent();
  }

  void setManualValues({
    double? frontDistance,
    double? downDistance,
    double? acceleration,
  }) {
    if (frontDistance != null) currentFrontDistanceCm = frontDistance;
    if (downDistance != null) currentDownDistanceCm = downDistance;
    if (acceleration != null) currentAcceleration = acceleration;
    emitCurrent();
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
