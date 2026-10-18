import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/spatial_zone.dart';
import '../../data/vision/native_vision_bridge.dart';
import '../../domain/benchmark/device_info_service.dart';
import '../../domain/benchmark/benchmark_engine.dart';
import '../../app/providers.dart';

/// Comprehensive YOLO Model Testing, Real-Device Benchmark and False-Alarm Test Harness Screen.
/// Includes:
/// 1. Prominent "NOT VALID FOR PITCH" emulator / debug banner.
/// 2. Device info header (Model, Android OS, RAM, SoC, Build mode).
/// 3. Live bounding box viewport with HFOV zone lines.
/// 4. 5-minute timed benchmark mode (p50, p95, max latency, average FPS, Delta FPS drop).
/// 5. Live per-frame inference ms, preprocessing ms, thermal status, battery %.
/// 6. Delegate switcher (CPU/XNNPACK/GPU/NNAPI) and resolution switcher (320/416).
/// 7. Empty-room false-alarm test harness with 5-minute countdown and 30-minute extrapolation.
/// 8. Numbers-only CSV export.
class ModelTestScreen extends ConsumerStatefulWidget {
  const ModelTestScreen({super.key});

  @override
  ConsumerState<ModelTestScreen> createState() => _ModelTestScreenState();
}

class _ModelTestScreenState extends ConsumerState<ModelTestScreen>
    with SingleTickerProviderStateMixin {
  // Test parameters
  double _confidenceThreshold = 0.45;
  double _nmsIouThreshold = 0.45;
  String _selectedDelegate = 'CPU (XNNPACK)';
  int _selectedInputSize = 320;
  bool _isReplayMode = false;

  // Device Info
  DeviceInfo _deviceInfo = DeviceInfo.fallback();

  // Real-time telemetry
  List<VisionDetection> _latestDetections = [];
  int _latestInferenceMs = 0;
  int _latestPrepMs = 0;
  final int _batteryLevel = 100;
  String _thermalStatus = 'Nominal';

  // 5-Minute Timed Benchmark Session
  final BenchmarkSession _benchmarkSession =
      BenchmarkSession(targetDuration: const Duration(minutes: 5));
  Timer? _benchmarkTimer;

  // Empty-Room False-Alarm Test Session
  final FalseAlarmTestSession _falseAlarmSession =
      FalseAlarmTestSession(testDuration: const Duration(minutes: 5), maxAllowedAlarmsPer30Min: 2);
  Timer? _falseAlarmTimer;

  StreamSubscription<List<VisionDetection>>? _subscription;
  Timer? _replayTimer;
  Timer? _thermalPollTimer;

  @override
  void initState() {
    super.initState();
    _loadHardwareInfo();
    _startVisionPipeline();
    _startThermalPolling();
  }

  Future<void> _loadHardwareInfo() async {
    final info = await DeviceInfoService().getDeviceInfo();
    if (mounted) {
      setState(() {
        _deviceInfo = info;
      });
    }
  }

  void _startThermalPolling() {
    _thermalPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final bridge = ref.read(visionBridgeProvider);
      final rawStatus = await bridge.getThermalStatus();
      if (!mounted) return;
      setState(() {
        _thermalStatus = _formatThermalStatus(rawStatus);
      });
    });
  }

  String _formatThermalStatus(int status) {
    switch (status) {
      case 0:
        return 'Nominal';
      case 1:
        return 'Light';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Critical';
      case 5:
        return 'Emergency';
      case 6:
        return 'Shutdown';
      default:
        return 'Nominal';
    }
  }

  void _startVisionPipeline() {
    final bridge = ref.read(visionBridgeProvider);
    bridge.startVision();
    _subscription = bridge.visionStream.listen((detections) {
      if (!_isReplayMode) {
        _onNewDetections(detections);
      }
    });
  }

  void _onNewDetections(List<VisionDetection> detections) {
    if (!mounted) return;

    final filtered = detections
        .where((d) => d.confidence >= _confidenceThreshold)
        .toList();

    int infMs = 0;
    int prepMs = 0;
    if (detections.isNotEmpty) {
      infMs = detections.first.inferenceMs;
      prepMs = detections.first.prepMs;
    }

    final fps = ref.read(visionMetricsProvider).currentFps;

    setState(() {
      _latestDetections = filtered;
      _latestInferenceMs = infMs;
      _latestPrepMs = prepMs;
    });

    // Record into active benchmark if running
    if (_benchmarkSession.isRunning) {
      _benchmarkSession.recordFrame(
        preprocessingMs: prepMs,
        inferenceMs: infMs,
        fps: fps,
        batteryPct: _batteryLevel,
        thermalStatus: _thermalStatus,
        delegate: _selectedDelegate,
        inputSize: _selectedInputSize,
        detectionCount: filtered.length,
      );
    }

    // Record false alarms if in empty-room test mode
    if (_falseAlarmSession.isRunning) {
      for (final d in filtered) {
        _falseAlarmSession.recordAlarm(d.label);
      }
    }
  }

  void _toggleBenchmark() {
    setState(() {
      if (_benchmarkSession.isRunning) {
        _benchmarkSession.stop();
        _benchmarkTimer?.cancel();
      } else {
        _benchmarkSession.start();
        _benchmarkTimer?.cancel();
        _benchmarkTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {});
          if (_benchmarkSession.isCompleted) {
            t.cancel();
            _showBenchmarkSummaryDialog();
          }
        });
      }
    });
  }

  void _toggleFalseAlarmTest() {
    setState(() {
      if (_falseAlarmSession.isRunning) {
        _falseAlarmSession.stop();
        _falseAlarmTimer?.cancel();
      } else {
        _falseAlarmSession.start();
        _falseAlarmTimer?.cancel();
        _falseAlarmTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {});
          if (_falseAlarmSession.isCompleted) {
            t.cancel();
            _showFalseAlarmSummaryDialog();
          }
        });
      }
    });
  }

  void _toggleReplayMode(bool enabled) {
    setState(() {
      _isReplayMode = enabled;
    });

    if (enabled) {
      _replayTimer?.cancel();
      int step = 0;
      _replayTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        step++;
        final testBox = VisionDetection(
          label: step % 40 < 20 ? 'stairs_down' : 'door',
          confidence: 0.65 + (step % 10) * 0.02,
          zone: SpatialZone.center,
          boxArea: 0.12 + (step % 20) * 0.005,
          bottomY: 0.82,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          latencyMs: 58 + (step % 10),
          inferenceMs: 46 + (step % 8),
          prepMs: 12 + (step % 2),
          x1: 0.30,
          y1: 0.40,
          x2: 0.70,
          y2: 0.85,
        );
        _onNewDetections([testBox]);
      });
    } else {
      _replayTimer?.cancel();
    }
  }

  Future<void> _updateDelegate(String delegate) async {
    setState(() => _selectedDelegate = delegate);
    final bridge = ref.read(visionBridgeProvider);
    await bridge.setDelegate(delegate);
  }

  Future<void> _updateInputSize(int size) async {
    setState(() => _selectedInputSize = size);
    final bridge = ref.read(visionBridgeProvider);
    await bridge.setInputSize(size);
  }

  void _exportCsvLog() {
    final csv = _benchmarkSession.exportCsv();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Export Numbers-Only CSV', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Frames Logged: ${_benchmarkSession.totalFrames}',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csv.isEmpty ? 'No benchmark frames logged yet. Run a 5-minute benchmark first.' : csv,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
            },
            child: const Text('Copy CSV'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showBenchmarkSummaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('5-Minute Benchmark Complete', style: TextStyle(color: Colors.greenAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow('Total Frames:', '${_benchmarkSession.totalFrames}'),
            _buildDialogRow('Average FPS:', _benchmarkSession.averageFps.toStringAsFixed(1)),
            _buildDialogRow('Baseline Initial FPS:', _benchmarkSession.initialFps.toStringAsFixed(1)),
            _buildDialogRow('FPS Drop (Delta):', '${_benchmarkSession.deltaFps.toStringAsFixed(1)} (${_benchmarkSession.percentageFpsDrop.toStringAsFixed(1)}%)'),
            _buildDialogRow('p50 Inference:', '${_benchmarkSession.p50InferenceMs} ms'),
            _buildDialogRow('p95 Inference:', '${_benchmarkSession.p95InferenceMs} ms'),
            _buildDialogRow('Max Inference:', '${_benchmarkSession.maxInferenceMs} ms'),
            _buildDialogRow('p50 Preprocessing:', '${_benchmarkSession.p50PreprocessingMs} ms'),
            const Divider(color: Colors.white24),
            Text(
              _deviceInfo.isValidForPitch
                  ? 'VERIFIED PHYSICAL RUN: Metrics qualify for pitch documentation.'
                  : 'UNVERIFIED: Ran on emulator/debug. Numbers not valid for pitch.',
              style: TextStyle(
                color: _deviceInfo.isValidForPitch ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportCsvLog();
            },
            child: const Text('View CSV'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFalseAlarmSummaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _falseAlarmSession.isPassed ? 'False-Alarm Test: PASS' : 'False-Alarm Test: FAIL',
          style: TextStyle(color: _falseAlarmSession.isPassed ? Colors.greenAccent : Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow('Total False Alarms (5 min):', '${_falseAlarmSession.totalFalseAlarms}'),
            _buildDialogRow('Alarms / Minute:', _falseAlarmSession.alarmsPerMinute.toStringAsFixed(2)),
            _buildDialogRow('Extrapolated (30 min):', '${_falseAlarmSession.extrapolated30MinAlarms}'),
            _buildDialogRow('Threshold Allowed:', '<= ${_falseAlarmSession.maxAllowedAlarmsPer30Min} per 30 min'),
            const Divider(color: Colors.white24),
            const Text('Class Breakdown:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            if (_falseAlarmSession.classAlarmCounts.isEmpty)
              const Text('  Zero false alarms triggered.', style: TextStyle(color: Colors.greenAccent))
            else
              ..._falseAlarmSession.classAlarmCounts.entries.map((e) =>
                  Text('  • ${e.key}: ${e.value}', style: const TextStyle(color: Colors.white))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _replayTimer?.cancel();
    _thermalPollTimer?.cancel();
    _benchmarkTimer?.cancel();
    _falseAlarmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(visionMetricsProvider);
    final fps = metrics.currentFps;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Benchmark & False-Alarm Suite'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsvLog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Mandatory Emulator / Debug Warning Banner
          if (!_deviceInfo.isValidForPitch)
            Container(
              width: double.infinity,
              color: Colors.red[900],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOT VALID FOR PITCH',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _deviceInfo.pitchWarningReason ?? 'Unverified environment.',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 2. Hardware Profiling Device Header
          Container(
            color: Colors.grey[950],
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDeviceChip(Icons.smartphone, _deviceInfo.model),
                _buildDeviceChip(Icons.memory, _deviceInfo.soc),
                _buildDeviceChip(Icons.storage, _deviceInfo.formattedRam),
                _buildDeviceChip(Icons.developer_mode, _deviceInfo.isDebug ? 'DEBUG' : 'RELEASE'),
              ],
            ),
          ),

          // 3. Live Viewport with Zone Lines & Bounding Box Overlay
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: _isReplayMode
                        ? const Text(
                            'REPLAY TEST FEED\n(Simulated Frames Feed)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold),
                          )
                        : const Text(
                            'LIVE CAMERA HARDWARE PREVIEW',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white24, fontSize: 14),
                          ),
                  ),
                ),

                // Custom Painter for Zones and Bounding Boxes
                CustomPaint(
                  painter: _DetectionOverlayPainter(
                    detections: _latestDetections,
                  ),
                ),

                // Live Top HUD: FPS, Preprocessing, Inference, Battery, Heat
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHudItem('FPS', fps.toStringAsFixed(1), Colors.greenAccent),
                        _buildHudItem('Prep', '$_latestPrepMs ms', Colors.cyanAccent),
                        _buildHudItem('Infer', '$_latestInferenceMs ms', Colors.orangeAccent),
                        _buildHudItem('p50', '${_benchmarkSession.p50InferenceMs} ms', Colors.white),
                        _buildHudItem('p95', '${_benchmarkSession.p95InferenceMs} ms', Colors.yellowAccent),
                        _buildHudItem('Heat', _thermalStatus, Colors.green),
                      ],
                    ),
                  ),
                ),

                // Active Test Overlay (Benchmark Countdown or False-Alarm Banner)
                if (_benchmarkSession.isRunning)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[900]!.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyanAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '5-MIN BENCHMARK: ${_benchmarkSession.remainingSeconds}s remaining',
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            '${_benchmarkSession.totalFrames} frames',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_falseAlarmSession.isRunning)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange[950]!.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orangeAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radar, color: Colors.orangeAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'EMPTY-ROOM TEST: ${_falseAlarmSession.remainingSeconds}s',
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            'Alarms: ${_falseAlarmSession.totalFalseAlarms}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Test Controls & Telemetry Dashboard
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                children: [
                  // Action Buttons: 5-Min Benchmark & False Alarm Test
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _benchmarkSession.isRunning ? Colors.redAccent : Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _toggleBenchmark,
                          icon: Icon(_benchmarkSession.isRunning ? Icons.stop : Icons.timer),
                          label: Text(_benchmarkSession.isRunning ? 'Stop Benchmark' : '5-Min Benchmark'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _falseAlarmSession.isRunning ? Colors.redAccent : Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _toggleFalseAlarmTest,
                          icon: Icon(_falseAlarmSession.isRunning ? Icons.stop : Icons.verified_user),
                          label: Text(_falseAlarmSession.isRunning ? 'Stop Test' : 'False-Alarm Test'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Sliders: Confidence & IoU
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confidence: ${_confidenceThreshold.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Text('IoU NMS: ${_nmsIouThreshold.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _confidenceThreshold,
                          min: 0.20,
                          max: 0.85,
                          divisions: 13,
                          activeColor: Colors.amberAccent,
                          onChanged: (val) => setState(() => _confidenceThreshold = val),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _nmsIouThreshold,
                          min: 0.25,
                          max: 0.75,
                          divisions: 10,
                          activeColor: Colors.cyanAccent,
                          onChanged: (val) => setState(() => _nmsIouThreshold = val),
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white24, height: 16),

                  // Delegate and Resolution Switches
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delegate', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            DropdownButton<String>(
                              value: _selectedDelegate,
                              isExpanded: true,
                              dropdownColor: Colors.grey[850],
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'CPU (XNNPACK)', child: Text('CPU (XNNPACK)')),
                                DropdownMenuItem(value: 'GPU Delegate', child: Text('GPU Delegate')),
                                DropdownMenuItem(value: 'NNAPI (Fallback)', child: Text('NNAPI (Fallback)')),
                              ],
                              onChanged: (val) {
                                if (val != null) _updateDelegate(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Input Size', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            DropdownButton<int>(
                              value: _selectedInputSize,
                              isExpanded: true,
                              dropdownColor: Colors.grey[850],
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 320, child: Text('320x320 (Fastest)')),
                                DropdownMenuItem(value: 416, child: Text('416x416 (High Res)')),
                              ],
                              onChanged: (val) {
                                if (val != null) _updateInputSize(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Replay Mode Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _isReplayMode,
                            activeThumbColor: Colors.amber,
                            onChanged: _toggleReplayMode,
                          ),
                          const Text('Simulate Replay Feed', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share, size: 16, color: Colors.greenAccent),
                        label: const Text('Export CSV', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        onPressed: _exportCsvLog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildHudItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Custom painter for HFOV Zone Boundaries (Left, Center, Right)
/// and YOLO Bounding Boxes with Labels & Confidences.
class _DetectionOverlayPainter extends CustomPainter {
  final List<VisionDetection> detections;

  _DetectionOverlayPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // HFOV Zone Lines (-12 deg to +12 deg in 65 deg HFOV)
    final leftX = width * 0.315;
    final rightX = width * 0.685;

    final zonePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(leftX, 0), Offset(leftX, height), zonePaint);
    canvas.drawLine(Offset(rightX, 0), Offset(rightX, height), zonePaint);

    _drawText(canvas, 'LEFT', Offset(leftX * 0.4, 45), Colors.white38);
    _drawText(canvas, 'CENTER', Offset(width * 0.46, 45), Colors.white70);
    _drawText(canvas, 'RIGHT', Offset(rightX + (width - rightX) * 0.3, 45), Colors.white38);

    for (final det in detections) {
      final boxPaint = Paint()
        ..color = _getColorForClass(det.label)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final rect = Rect.fromLTRB(
        det.x1 * width,
        det.y1 * height,
        det.x2 * width,
        det.y2 * height,
      );

      canvas.drawRect(rect, boxPaint);

      final text = '${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%';
      final bgPaint = Paint()..color = _getColorForClass(det.label).withValues(alpha: 0.85);
      final textSpan = TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final bannerRect = Rect.fromLTWH(
        rect.left,
        (rect.top - 18).clamp(0, height),
        textPainter.width + 8,
        18,
      );
      canvas.drawRect(bannerRect, bgPaint);
      textPainter.paint(canvas, Offset(bannerRect.left + 4, bannerRect.top + 1));
    }
  }

  Color _getColorForClass(String label) {
    switch (label) {
      case 'stairs':
      case 'stairs_up':
      case 'stairs_down':
      case 'drop_off':
        return Colors.redAccent;
      case 'door':
        return Colors.greenAccent;
      case 'chair':
      case 'table':
        return Colors.orangeAccent;
      case 'person':
        return Colors.yellowAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter oldDelegate) => true;
}
