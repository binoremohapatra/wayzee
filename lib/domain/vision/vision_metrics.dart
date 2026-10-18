import 'dart:collection';

class VisionMetrics {
  final ListQueue<int> _latenciesMs = ListQueue();
  final ListQueue<int> _frameTimestamps = ListQueue();
  final ListQueue<int> _alertLatenciesMs = ListQueue();
  final ListQueue<int> _falseAlarmTimestamps = ListQueue();

  final int maxSampleWindow;

  VisionMetrics({this.maxSampleWindow = 100});

  void recordFrame(int latencyMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameTimestamps.add(now);
    _latenciesMs.add(latencyMs);

    // Keep window bounded
    while (_frameTimestamps.length > maxSampleWindow) {
      _frameTimestamps.removeFirst();
    }
    while (_latenciesMs.length > maxSampleWindow) {
      _latenciesMs.removeFirst();
    }
  }

  void recordAlertLatency(int alertLatencyMs) {
    _alertLatenciesMs.add(alertLatencyMs);
    while (_alertLatenciesMs.length > maxSampleWindow) {
      _alertLatenciesMs.removeFirst();
    }
  }

  void recordFalseAlarm() {
    _falseAlarmTimestamps.add(DateTime.now().millisecondsSinceEpoch);
  }

  double get currentFps {
    if (_frameTimestamps.length < 2) return 0.0;
    final durationSec = (_frameTimestamps.last - _frameTimestamps.first) / 1000.0;
    if (durationSec <= 0) return 0.0;
    return (_frameTimestamps.length - 1) / durationSec;
  }

  double get p50LatencyMs {
    if (_latenciesMs.isEmpty) return 0.0;
    final sorted = _latenciesMs.toList()..sort();
    final mid = sorted.length ~/ 2;
    return sorted[mid].toDouble();
  }

  double get p95LatencyMs {
    if (_latenciesMs.isEmpty) return 0.0;
    final sorted = _latenciesMs.toList()..sort();
    final index = (sorted.length * 0.95).clamp(0, sorted.length - 1).toInt();
    return sorted[index].toDouble();
  }

  double get averageAlertLatencyMs {
    if (_alertLatenciesMs.isEmpty) return 0.0;
    final sum = _alertLatenciesMs.reduce((a, b) => a + b);
    return sum / _alertLatenciesMs.length;
  }

  double get falseAlarmsPerMinute {
    final oneMinuteAgo = DateTime.now().millisecondsSinceEpoch - 60000;
    _falseAlarmTimestamps.removeWhere((ts) => ts < oneMinuteAgo);
    return _falseAlarmTimestamps.length.toDouble();
  }
}
