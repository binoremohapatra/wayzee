import 'package:flutter/material.dart';
import '../../core/theme/accessible_colors.dart';
import '../../data/sensors/mock_cane_source.dart';
import '../../domain/vision/vision_metrics.dart';
import '../widgets/accessible_scaffold.dart';
import '../widgets/accessible_tactile_button.dart';

class DebugScreen extends StatefulWidget {
  final MockCaneSource mockCaneSource;
  final VisionMetrics visionMetrics;

  const DebugScreen({
    super.key,
    required this.mockCaneSource,
    required this.visionMetrics,
  });

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  late double _frontDistance;
  late double _downDistance;
  late double _acceleration;

  @override
  void initState() {
    super.initState();
    _frontDistance = widget.mockCaneSource.currentFrontDistanceCm;
    _downDistance = widget.mockCaneSource.currentDownDistanceCm;
    _acceleration = widget.mockCaneSource.currentAcceleration;
  }

  void _applyScenario(CaneScenario scenario) {
    widget.mockCaneSource.loadScenario(scenario);
    setState(() {
      _frontDistance = widget.mockCaneSource.currentFrontDistanceCm;
      _downDistance = widget.mockCaneSource.currentDownDistanceCm;
      _acceleration = widget.mockCaneSource.currentAcceleration;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fps = widget.visionMetrics.currentFps.toStringAsFixed(1);
    final p50 = widget.visionMetrics.p50LatencyMs.toStringAsFixed(0);
    final p95 = widget.visionMetrics.p95LatencyMs.toStringAsFixed(0);
    final falseAlarms = widget.visionMetrics.falseAlarmsPerMinute.toStringAsFixed(0);

    return AccessibleScaffold(
      title: 'Sensor & Vision Debugger',
      spokenScreenTitle: 'Sensor and vision simulation debugger',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Telemetry Cards
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AccessibleColors.surface,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AccessibleColors.tactileAccent, width: 2.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LIVE PERFORMANCE METRICS',
                    style: TextStyle(
                      color: AccessibleColors.tactileAccent,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text('Inference FPS: $fps FPS', style: const TextStyle(color: Colors.white, fontSize: 18.0)),
                  Text('Latency p50: ${p50}ms  |  p95: ${p95}ms', style: const TextStyle(color: Colors.white, fontSize: 18.0)),
                  Text('False Alarms / Min: $falseAlarms', style: const TextStyle(color: Colors.white, fontSize: 18.0)),
                  const SizedBox(height: 12.0),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccessibleColors.tactileAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('OPEN MODEL BENCHMARK & TEST SCREEN', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pushNamed(context, '/model_test'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Scripted Scenario Buttons
            const Text(
              'SCRIPTED TEST SCENARIOS',
              style: TextStyle(color: AccessibleColors.textSecondary, fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            AccessibleTactileButton(
              label: 'Trigger Stairs Down (Drop-Off)',
              isDestructive: true,
              onPressed: () => _applyScenario(CaneScenario.stairsDownAhead),
            ),
            const SizedBox(height: 12.0),
            AccessibleTactileButton(
              label: 'Trigger Obstacle Ahead (<50cm)',
              isDestructive: true,
              onPressed: () => _applyScenario(CaneScenario.obstacleClose),
            ),
            const SizedBox(height: 12.0),
            AccessibleTactileButton(
              label: 'Normal Walking (Clear Path)',
              onPressed: () => _applyScenario(CaneScenario.normalWalking),
            ),
            const SizedBox(height: 12.0),
            AccessibleTactileButton(
              label: 'Stationary (Stop Movement)',
              onPressed: () => _applyScenario(CaneScenario.stationary),
            ),
            const SizedBox(height: 24.0),

            // Distance Sliders
            const Text(
              'MANUAL CANE DISTANCE SLIDERS',
              style: TextStyle(color: AccessibleColors.textSecondary, fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Front Distance: ${_frontDistance.toStringAsFixed(0)} cm',
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
            ),
            Slider(
              value: _frontDistance,
              min: 20.0,
              max: 400.0,
              activeColor: AccessibleColors.tactileAccent,
              onChanged: (val) {
                setState(() => _frontDistance = val);
                widget.mockCaneSource.setManualValues(frontDistance: val);
              },
            ),
            const SizedBox(height: 8.0),
            Text(
              'Down Ground Distance: ${_downDistance.toStringAsFixed(0)} cm (Normal: 110cm)',
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
            ),
            Slider(
              value: _downDistance,
              min: 50.0,
              max: 300.0,
              activeColor: AccessibleColors.warning,
              onChanged: (val) {
                setState(() => _downDistance = val);
                widget.mockCaneSource.setManualValues(downDistance: val);
              },
            ),
            const SizedBox(height: 8.0),
            Text(
              'IMU Acceleration: ${_acceleration.toStringAsFixed(1)} m/s²',
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
            ),
          ],
        ),
      ),
    );
  }
}
