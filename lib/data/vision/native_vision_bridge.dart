import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/models/spatial_zone.dart';
import '../../domain/safety/camera_health_monitor.dart';

class VisionDetection {
  final String label;
  final double confidence;
  final SpatialZone zone;
  final double boxArea;
  final double bottomY;
  final int timestamp;
  final int latencyMs;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const VisionDetection({
    required this.label,
    required this.confidence,
    required this.zone,
    required this.boxArea,
    required this.bottomY,
    required this.timestamp,
    this.latencyMs = 0,
    this.x1 = 0.0,
    this.y1 = 0.0,
    this.x2 = 0.0,
    this.y2 = 0.0,
  });

  factory VisionDetection.fromMap(Map<dynamic, dynamic> map) {
    final zoneString = map['zone'] as String? ?? 'center';
    final zone = zoneString == 'left'
        ? SpatialZone.left
        : (zoneString == 'right' ? SpatialZone.right : SpatialZone.center);

    return VisionDetection(
      label: map['label'] as String? ?? 'obstacle',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      zone: zone,
      boxArea: (map['boxArea'] as num?)?.toDouble() ?? 0.0,
      bottomY: (map['bottomY'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      x1: (map['x1'] as num?)?.toDouble() ?? 0.0,
      y1: (map['y1'] as num?)?.toDouble() ?? 0.0,
      x2: (map['x2'] as num?)?.toDouble() ?? 0.0,
      y2: (map['y2'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

abstract class VisionBridge {
  Future<bool> startForegroundService();
  Future<bool> stopForegroundService();
  Future<bool> startVision();
  Future<bool> stopVision();
  Future<void> setStationary(bool isStationary);
  Future<int> getThermalStatus();
  Stream<List<VisionDetection>> get visionStream;
  Stream<String> get hardwareKeyStream;
  Stream<CameraFrameHealth> get cameraHealthStream => const Stream.empty();
}

class NativeVisionBridge implements VisionBridge {
  static const MethodChannel _serviceChannel = MethodChannel('com.wayze/service');
  static const EventChannel _visionChannel = EventChannel('com.wayze/vision_stream');
  static const EventChannel _hardwareKeyChannel = EventChannel('com.wayze/hardware_keys');

  final StreamController<CameraFrameHealth> _cameraHealthController =
      StreamController<CameraFrameHealth>.broadcast();

  Stream<List<VisionDetection>>? _visionStream;
  Stream<String>? _hardwareKeyStream;

  @override
  Stream<CameraFrameHealth> get cameraHealthStream => _cameraHealthController.stream;

  @override
  Future<bool> startForegroundService() async {
    try {
      final res = await _serviceChannel.invokeMethod<bool>('startForegroundService');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopForegroundService() async {
    try {
      final res = await _serviceChannel.invokeMethod<bool>('stopForegroundService');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startVision() async {
    try {
      final res = await _serviceChannel.invokeMethod<bool>('startVision');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopVision() async {
    try {
      final res = await _serviceChannel.invokeMethod<bool>('stopVision');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setStationary(bool isStationary) async {
    try {
      await _serviceChannel.invokeMethod<void>('setStationary', {'isStationary': isStationary});
    } catch (_) {}
  }

  @override
  Future<int> getThermalStatus() async {
    try {
      final status = await _serviceChannel.invokeMethod<int>('getThermalStatus');
      return status ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Stream<List<VisionDetection>> get visionStream {
    _visionStream ??= _visionChannel
        .receiveBroadcastStream()
        .map<List<VisionDetection>>((dynamic event) {
      if (event is Map) {
        final detectionsList = event['detections'] as List? ?? [];
        if (event.containsKey('quality')) {
          final q = event['quality'] as Map? ?? {};
          _cameraHealthController.add(CameraFrameHealth(
            meanLuminance: (q['meanLuminance'] as num?)?.toDouble() ?? 0.0,
            varianceLuminance: (q['varianceLuminance'] as num?)?.toDouble() ?? 0.0,
            isDark: q['isDark'] as bool? ?? false,
            isBlocked: q['isBlocked'] as bool? ?? false,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (q['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
            ),
          ));
        }
        return detectionsList
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => VisionDetection.fromMap(e))
            .toList();
      } else if (event is List) {
        return event
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => VisionDetection.fromMap(e))
            .toList();
      }
      return <VisionDetection>[];
    });
    return _visionStream!;
  }

  @override
  Stream<String> get hardwareKeyStream {
    _hardwareKeyStream ??= _hardwareKeyChannel
        .receiveBroadcastStream()
        .map<String>((dynamic event) => event.toString());
    return _hardwareKeyStream!;
  }
}
