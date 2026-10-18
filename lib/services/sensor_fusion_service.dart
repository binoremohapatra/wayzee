import 'dart:async';
import 'dart:ui';
import '../detector/detector.dart';

// Alert levels for multi-modal alerts
enum AlertLevel {
  none,
  mild,
  medium,
  severe,
  critical,
}

// ESP32 sensor data model
class ESP32SensorData {
  final double fwdCm;  // Forward distance in cm
  final double downCm;  // Down distance in cm
  final double headingDeg;  // Heading in degrees
  final String beacon;  // Current beacon name
  final int rssi;  // Beacon RSSI
  final int buttonState;  // Button state bitmask

  ESP32SensorData({
    required this.fwdCm,
    required this.downCm,
    required this.headingDeg,
    required this.beacon,
    required this.rssi,
    required this.buttonState,
  });

  // Simulated data for testing
  factory ESP32SensorData.simulated() {
    return ESP32SensorData(
      fwdCm: 150.0,
      downCm: 200.0,
      headingDeg: 0.0,
      beacon: '',
      rssi: -100,
      buttonState: 0,
    );
  }
}

// Fused detection result
class FusedDetection {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final double esp32Distance;
  final bool esp32Detected;
  final bool aiDetected;
  final double fusedConfidence;
  final AlertLevel alertLevel;

  FusedDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.esp32Distance,
    required this.esp32Detected,
    required this.aiDetected,
    required this.fusedConfidence,
    required this.alertLevel,
  });
}

class SensorFusionService {
  // Detection thresholds
  static const double fwdDangerCm = 50.0;
  static const double fwdNearCm = 100.0;
  static const double fwdMidCm = 150.0;
  static const double downDropCm = 200.0;
  static const double downDropHyst = 150.0;

  // Confidence thresholds
  static const double aiConfidenceThreshold = 0.45;
  static const double esp32ConfidenceHigh = 0.9;
  static const double esp32ConfidenceMedium = 0.7;
  static const double esp32ConfidenceLow = 0.5;

  // Adaptive threshold modifiers
  double _userSpeedModifier = 1.0;
  double _environmentModifier = 1.0;

  // Context memory
  final List<Detection> _recentDetections = [];
  final int _maxHistorySize = 10;

  // ESP32 data
  ESP32SensorData? _esp32Data;

  // Stream for fused detections
  final _fusedDetectionController = StreamController<FusedDetection>.broadcast();

  Stream<FusedDetection> get fusedDetections => _fusedDetectionController.stream;

  // Set ESP32 data
  void updateESP32Data(ESP32SensorData data) {
    _esp32Data = data;
    _processFusion();
  }

  // Adaptive threshold calculation
  double _getAdaptiveForwardThreshold() {
    double base = fwdDangerCm;
    return base * _userSpeedModifier * _environmentModifier;
  }

  // Calculate ESP32 detection confidence based on distance
  double _calculateESP32Confidence(double distance) {
    if (distance < _getAdaptiveForwardThreshold()) {
      return esp32ConfidenceHigh;
    } else if (distance < fwdNearCm * _userSpeedModifier) {
      return esp32ConfidenceMedium;
    } else if (distance < fwdMidCm * _userSpeedModifier) {
      return esp32ConfidenceLow;
    }
    return 0.0;
  }

  // Fuse AI and ESP32 detections
  void _processFusion() {
    if (_recentDetections.isEmpty) return;

    for (final aiDetection in _recentDetections) {
      final esp32Dist = _esp32Data?.fwdCm ?? 999.0;
      final esp32Conf = _calculateESP32Confidence(esp32Dist);
      final esp32Detected = esp32Conf > 0.3;

      // Sensor fusion logic
      double fusedConf;
      AlertLevel alertLevel;

      if (esp32Detected && aiDetection.confidence > aiConfidenceThreshold) {
        // Both detected - HIGH CONFIDENCE
        fusedConf = (esp32Conf + aiDetection.confidence) / 2;
        alertLevel = _determineAlertLevel(fusedConf, esp32Dist);
      } else if (esp32Detected && aiDetection.confidence <= aiConfidenceThreshold) {
        // ESP32 only - MEDIUM CONFIDENCE (possible AI miss)
        fusedConf = esp32Conf * 0.8;
        alertLevel = _determineAlertLevel(fusedConf, esp32Dist);
      } else if (!esp32Detected && aiDetection.confidence > aiConfidenceThreshold) {
        // AI only - MEDIUM CONFIDENCE (possible ESP32 false positive)
        fusedConf = aiDetection.confidence * 0.8;
        alertLevel = _determineAlertLevel(fusedConf, esp32Dist);
      } else {
        // Neither detected - NONE
        fusedConf = 0.0;
        alertLevel = AlertLevel.none;
      }

      final fusedDetection = FusedDetection(
        label: aiDetection.label,
        confidence: aiDetection.confidence,
        boundingBox: aiDetection.boundingBox,
        esp32Distance: esp32Dist,
        esp32Detected: esp32Detected,
        aiDetected: aiDetection.confidence > aiConfidenceThreshold,
        fusedConfidence: fusedConf,
        alertLevel: alertLevel,
      );

      _fusedDetectionController.add(fusedDetection);
    }
  }

  // Determine alert level based on confidence and distance
  AlertLevel _determineAlertLevel(double confidence, double distance) {
    if (confidence >= 0.8) {
      if (distance < fwdDangerCm) return AlertLevel.critical;
      if (distance < fwdNearCm) return AlertLevel.severe;
      return AlertLevel.medium;
    } else if (confidence >= 0.6) {
      if (distance < fwdDangerCm) return AlertLevel.severe;
      if (distance < fwdNearCm) return AlertLevel.medium;
      return AlertLevel.mild;
    } else {
      if (distance < fwdDangerCm) return AlertLevel.medium;
      return AlertLevel.mild;
    }
  }

  // Add AI detection result
  void addAIDetection(Detection detection) {
    _recentDetections.add(detection);
    if (_recentDetections.length > _maxHistorySize) {
      _recentDetections.removeAt(0);
    }
    _processFusion();
  }

  // Set user speed modifier (adaptive threshold)
  void setUserSpeedModifier(double modifier) {
    _userSpeedModifier = modifier < 0.5 ? 0.5 : (modifier > 2.0 ? 2.0 : modifier);
  }

  // Set environment modifier (adaptive threshold)
  void setEnvironmentModifier(double modifier) {
    _environmentModifier = modifier < 0.5 ? 0.5 : (modifier > 2.0 ? 2.0 : modifier);
  }

  // Get current adaptive thresholds
  Map<String, double> getAdaptiveThresholds() {
    return {
      'fwd_danger': _getAdaptiveForwardThreshold(),
      'fwd_near': fwdNearCm * _userSpeedModifier * _environmentModifier,
      'fwd_mid': fwdMidCm * _userSpeedModifier * _environmentModifier,
    };
  }

  // Clear detection history
  void clearHistory() {
    _recentDetections.clear();
  }

  // Dispose
  void dispose() {
    _fusedDetectionController.close();
  }
}
