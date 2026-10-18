import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../widgets/big_button.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';
import '../../detector/composite_detector.dart';
import '../../services/sensor_fusion_service.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  String _detectionStatus = 'No objects detected';
  CompositeDetector? _detector;
  SensorFusionService? _fusionService;
  StreamSubscription? _fusionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeDetector();
    _initializeFusion();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _detectionStatus = 'No camera available';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
      
      // Speak that camera is ready
      Fx.speak?.call('Camera ready. Point at obstacles to detect.');
      
      // Start detection loop
      _startDetectionLoop();
    } catch (e) {
      setState(() {
        _detectionStatus = 'Camera error: $e';
      });
    }
  }

  Future<void> _initializeDetector() async {
    _detector = await CompositeDetector.create();
    await _detector!.loadModel();
    
    if (_detector!.hasCustomModel) {
      setState(() {
        _detectionStatus = 'Model loaded: door, stairs detection ready';
      });
    } else {
      setState(() {
        _detectionStatus = 'Model not loaded';
      });
    }
  }

  void _initializeFusion() {
    _fusionService = SensorFusionService();
    
    // Simulate ESP32 data for testing
    _fusionService!.updateESP32Data(ESP32SensorData.simulated());
    
    // Listen to fused detections
    _fusionSubscription = _fusionService!.fusedDetections.listen((fused) {
      setState(() {
        _detectionStatus = 'Fused: ${fused.label} (${(fused.fusedConfidence * 100).toStringAsFixed(0)}%) - ${fused.alertLevel.name.toUpperCase()}';
      });
      
      // Multi-modal alert based on alert level
      switch (fused.alertLevel) {
        case AlertLevel.critical:
          Fx.speak?.call('Critical: ${fused.label} ahead');
          Fx.haptic(Sig.sos);
          break;
        case AlertLevel.severe:
          Fx.speak?.call('${fused.label} ahead');
          Fx.haptic(Sig.error);
          break;
        case AlertLevel.medium:
          Fx.haptic(Sig.primary);
          break;
        case AlertLevel.mild:
          Fx.haptic(Sig.tick);
          break;
        case AlertLevel.none:
          break;
      }
    });
  }

  void _startDetectionLoop() async {
    while (_isInitialized && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      
      if (_controller == null || !_controller!.value.isInitialized) continue;
      
      try {
        final image = await _controller!.takePicture();
        if (_detector != null && _detector!.hasCustomModel) {
          final detections = await _detector!.detect(image);
          
          if (detections.isNotEmpty) {
            // Add to sensor fusion
            for (final detection in detections) {
              _fusionService?.addAIDetection(detection);
            }
            
            String detectedObjects = detections.map((d) => '${d.label} (${(d.confidence * 100).toStringAsFixed(0)}%)').join(', ');
            setState(() {
              _detectionStatus = 'AI detected: $detectedObjects';
            });
          } else {
            setState(() {
              _detectionStatus = 'No obstacles detected';
            });
          }
        }
      } catch (e) {
        debugPrint('Detection loop error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector?.close();
    _fusionSubscription?.cancel();
    _fusionService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Obstacle Detection',
      spokenIntro: 'Camera detection screen. Point camera at obstacles to detect.',
      body: [
        if (!_isInitialized)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_detectionStatus),
              ],
            ),
          )
        else
          Column(
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3A3A3A)),
                ),
                child: Text(
                  _detectionStatus,
                  style: const TextStyle(fontSize: 18, color: Color(0xFFEDEDED)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
      ],
      bottom: BigButton(
        label: 'Back to Home',
        icon: Icons.arrow_back_rounded,
        onPressed: () {
          Fx.haptic(Sig.back);
          Navigator.pop(context);
        },
      ),
    );
  }
}
