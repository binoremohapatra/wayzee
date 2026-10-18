import 'dart:math' as math;

/// Single measurement record for an inference frame.
class BenchmarkFrameRecord {
  final int timestamp;
  final int frameIndex;
  final int preprocessingMs;
  final int inferenceMs;
  final int totalLatencyMs;
  final double fps;
  final int batteryPct;
  final String thermalStatus;
  final String delegate;
  final int inputSize;
  final int detectionCount;

  const BenchmarkFrameRecord({
    required this.timestamp,
    required this.frameIndex,
    required this.preprocessingMs,
    required this.inferenceMs,
    required this.totalLatencyMs,
    required this.fps,
    required this.batteryPct,
    required this.thermalStatus,
    required this.delegate,
    required this.inputSize,
    required this.detectionCount,
  });

  /// Produces numbers-only CSV row representation
  String toCsvRow(int p50, int p95) {
    return '$timestamp,$frameIndex,$preprocessingMs,$inferenceMs,$totalLatencyMs,'
        '${fps.toStringAsFixed(2)},$batteryPct,$p50,$p95,$detectionCount,$inputSize,"$delegate"';
  }
}

/// 5-Minute Timed Benchmark Session tracking p50, p95, max latency, average FPS,
/// and thermal-induced FPS drops over time (Delta FPS).
class BenchmarkSession {
  final Duration targetDuration;
  final List<BenchmarkFrameRecord> _records = [];
  final List<double> _earlyFpsSamples = [];
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isRunning = false;

  BenchmarkSession({
    this.targetDuration = const Duration(minutes: 5),
  });

  bool get isRunning => _isRunning;
  bool get isCompleted =>
      _records.isNotEmpty && elapsedSeconds >= targetDuration.inSeconds;

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!).inSeconds;
  }

  int get remainingSeconds {
    final rem = targetDuration.inSeconds - elapsedSeconds;
    return rem > 0 ? rem : 0;
  }

  double get progressRatio {
    if (targetDuration.inSeconds == 0) return 1.0;
    return (elapsedSeconds / targetDuration.inSeconds).clamp(0.0, 1.0);
  }

  int get totalFrames => _records.length;

  void start() {
    _records.clear();
    _earlyFpsSamples.clear();
    _startTime = DateTime.now();
    _endTime = null;
    _isRunning = true;
  }

  void stop() {
    if (_isRunning) {
      _endTime = DateTime.now();
      _isRunning = false;
    }
  }

  void recordFrame({
    required int preprocessingMs,
    required int inferenceMs,
    required double fps,
    required int batteryPct,
    required String thermalStatus,
    required String delegate,
    required int inputSize,
    required int detectionCount,
  }) {
    if (!_isRunning) return;

    final now = DateTime.now();
    final elapsedSec = now.difference(_startTime!).inSeconds;

    final record = BenchmarkFrameRecord(
      timestamp: now.millisecondsSinceEpoch,
      frameIndex: _records.length + 1,
      preprocessingMs: preprocessingMs,
      inferenceMs: inferenceMs,
      totalLatencyMs: preprocessingMs + inferenceMs,
      fps: fps,
      batteryPct: batteryPct,
      thermalStatus: thermalStatus,
      delegate: delegate,
      inputSize: inputSize,
      detectionCount: detectionCount,
    );
    _records.add(record);

    // Track baseline FPS during initial samples (first 5 frames)
    if (_earlyFpsSamples.length < 5 && fps > 0) {
      _earlyFpsSamples.add(fps);
    }

    if (elapsedSec >= targetDuration.inSeconds) {
      stop();
    }
  }

  double get initialFps {
    if (_earlyFpsSamples.isEmpty) return currentFps;
    return _earlyFpsSamples.reduce((a, b) => a + b) / _earlyFpsSamples.length;
  }

  double get currentFps {
    if (_records.isEmpty) return 0.0;
    return _records.last.fps;
  }

  double get averageFps {
    if (_records.isEmpty || elapsedSeconds == 0) return 0.0;
    return _records.length / elapsedSeconds;
  }

  /// Drop in FPS from early baseline to current (indicates thermal throttling)
  double get deltaFps {
    final base = initialFps;
    final curr = currentFps;
    if (base <= 0 || curr <= 0) return 0.0;
    return math.max(0.0, base - curr);
  }

  double get percentageFpsDrop {
    final base = initialFps;
    if (base <= 0) return 0.0;
    return (deltaFps / base) * 100.0;
  }

  int get p50InferenceMs {
    if (_records.isEmpty) return 0;
    final list = _records.map((r) => r.inferenceMs).toList()..sort();
    return list[list.length ~/ 2];
  }

  int get p95InferenceMs {
    if (_records.isEmpty) return 0;
    final list = _records.map((r) => r.inferenceMs).toList()..sort();
    final idx = (list.length * 0.95).floor().clamp(0, list.length - 1);
    return list[idx];
  }

  int get maxInferenceMs {
    if (_records.isEmpty) return 0;
    return _records.map((r) => r.inferenceMs).reduce(math.max);
  }

  int get p50PreprocessingMs {
    if (_records.isEmpty) return 0;
    final list = _records.map((r) => r.preprocessingMs).toList()..sort();
    return list[list.length ~/ 2];
  }

  int get p95PreprocessingMs {
    if (_records.isEmpty) return 0;
    final list = _records.map((r) => r.preprocessingMs).toList()..sort();
    final idx = (list.length * 0.95).floor().clamp(0, list.length - 1);
    return list[idx];
  }

  /// Exports benchmark metrics as numbers-only CSV
  String exportCsv() {
    final buf = StringBuffer();
    buf.writeln('timestamp_epoch_ms,frame_idx,prep_ms,inference_ms,total_ms,fps,battery_pct,p50_ms,p95_ms,detection_count,input_size,delegate');
    final p50 = p50InferenceMs;
    final p95 = p95InferenceMs;
    for (final r in _records) {
      buf.writeln(r.toCsvRow(p50, p95));
    }
    return buf.toString();
  }
}

/// Empty-Room False-Alarm Test Harness.
/// Evaluates model stability when pointed at an empty space or plain wall for 5 minutes.
/// Extrapolates to 30 minutes (count * 6) and evaluates PASS / FAIL against threshold (<= 2 per 30m).
class FalseAlarmTestSession {
  final Duration testDuration;
  final int maxAllowedAlarmsPer30Min;
  final Map<String, int> _classAlarmCounts = {};
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isRunning = false;

  FalseAlarmTestSession({
    this.testDuration = const Duration(minutes: 5),
    this.maxAllowedAlarmsPer30Min = 2,
  });

  bool get isRunning => _isRunning;
  bool get isCompleted => elapsedSeconds >= testDuration.inSeconds;

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!).inSeconds;
  }

  int get remainingSeconds {
    final rem = testDuration.inSeconds - elapsedSeconds;
    return rem > 0 ? rem : 0;
  }

  Map<String, int> get classAlarmCounts => Map.unmodifiable(_classAlarmCounts);

  int get totalFalseAlarms =>
      _classAlarmCounts.values.fold(0, (acc, c) => acc + c);

  void start() {
    _classAlarmCounts.clear();
    _startTime = DateTime.now();
    _endTime = null;
    _isRunning = true;
  }

  void stop() {
    if (_isRunning) {
      _endTime = DateTime.now();
      _isRunning = false;
    }
  }

  /// Record an alert fired during the empty room test
  void recordAlarm(String label) {
    if (!_isRunning) return;
    final normalized = label.trim().toLowerCase();
    _classAlarmCounts[normalized] = (_classAlarmCounts[normalized] ?? 0) + 1;

    if (elapsedSeconds >= testDuration.inSeconds) {
      stop();
    }
  }

  double get alarmsPerMinute {
    final elapsedSec = elapsedSeconds;
    if (elapsedSec <= 0) return 0.0;
    return (totalFalseAlarms / elapsedSec) * 60.0;
  }

  /// Extrapolate to 30 minutes: (total / elapsedMinutes) * 30
  /// For a full 5-minute test, this is exactly totalFalseAlarms * 6.
  int get extrapolated30MinAlarms {
    final elapsedMin = elapsedSeconds / 60.0;
    if (elapsedMin <= 0) return totalFalseAlarms * 6;
    return (alarmsPerMinute * 30.0).round();
  }

  /// PASS if extrapolated alarms <= maxAllowedAlarmsPer30Min (default: 2)
  bool get isPassed => extrapolated30MinAlarms <= maxAllowedAlarmsPer30Min;

  String exportSummary() {
    final buf = StringBuffer();
    buf.writeln('=== EMPTY-ROOM FALSE-ALARM TEST REPORT ===');
    buf.writeln('Duration Tested: ${elapsedSeconds}s / ${testDuration.inSeconds}s');
    buf.writeln('Total False Alarms: $totalFalseAlarms');
    buf.writeln('Alarms / Minute: ${alarmsPerMinute.toStringAsFixed(2)}');
    buf.writeln('Extrapolated (30 min): $extrapolated30MinAlarms (Threshold: <= $maxAllowedAlarmsPer30Min)');
    buf.writeln('Result: ${isPassed ? "PASS" : "FAIL"}');
    buf.writeln('Per-Class Breakdown:');
    if (_classAlarmCounts.isEmpty) {
      buf.writeln('  (Zero false alarms detected - Clean)');
    } else {
      _classAlarmCounts.forEach((label, count) {
        buf.writeln('  - $label: $count alarms');
      });
    }
    return buf.toString();
  }
}
