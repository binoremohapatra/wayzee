import 'package:flutter/material.dart';

class CaneSensorData {
  final double distanceCm; // 0-300 cm
  final bool stairsAhead;
  final bool dropOffAhead;

  CaneSensorData({
    required this.distanceCm,
    this.stairsAhead = false,
    this.dropOffAhead = false,
  });

  bool get isObstacleNear => distanceCm < 100;
  bool get isObstacleVeryClose => distanceCm < 50;
  bool get isDanger => stairsAhead || dropOffAhead || isObstacleVeryClose;
}

class SimulatedCaneSensor extends ChangeNotifier {
  CaneSensorData _data = CaneSensorData(distanceCm: 150);

  CaneSensorData get data => _data;

  void setDistance(double distanceCm) {
    _data = CaneSensorData(
      distanceCm: distanceCm.clamp(0, 300),
      stairsAhead: _data.stairsAhead,
      dropOffAhead: _data.dropOffAhead,
    );
    notifyListeners();
  }

  void setStairsAhead(bool value) {
    _data = CaneSensorData(
      distanceCm: _data.distanceCm,
      stairsAhead: value,
      dropOffAhead: _data.dropOffAhead,
    );
    notifyListeners();
  }

  void setDropOffAhead(bool value) {
    _data = CaneSensorData(
      distanceCm: _data.distanceCm,
      stairsAhead: _data.stairsAhead,
      dropOffAhead: value,
    );
    notifyListeners();
  }

  void reset() {
    _data = CaneSensorData(distanceCm: 150);
    notifyListeners();
  }
}
