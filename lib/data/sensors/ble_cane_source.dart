import 'dart:async';
import '../../domain/fusion/sensor_source.dart';

/// Bluetooth Low Energy Smart Cane source.
/// Documented GATT Profile for future ESP32-S3 cane hardware integration:
/// Service UUID: 0000FFE0-0000-1000-8000-00805F9B34FB (Wayze Cane Telemetry)
/// Characteristic UUID: 0000FFE1-0000-1000-8000-00805F9B34FB (ToF + IMU + Battery, Notify)
///
/// Packet Format (14-16 Bytes Little-Endian):
/// [0..1] uint16: seq (sequence counter)
/// [2..5] uint32: ts (cane uptime timestamp ms)
/// [6..7] uint16: dist_front_cm
/// [8..9] uint16: dist_down_cm
/// [10..11] int16: tilt (pitch * 10)
/// [12] uint8: flags (bit 0: drop_off_active, bit 1: barrier_active)
/// [13] uint8: battery (percentage 0..100)
class BleCaneSource implements SensorSource {
  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  final void Function()? onDisconnect;

  bool _isConnected = false;
  int _lastSeq = 0;
  int _batteryLevel = 100;

  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  BleCaneSource({this.onDisconnect});

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  bool get isConnected => _isConnected;
  int get batteryLevel => _batteryLevel;
  int get lastSeq => _lastSeq;

  @override
  Future<void> start() async {
    // When real BLE hardware is bonded:
    // 1. Scan for serviceUuid
    // 2. Connect and subscribe to characteristicUuid notifications
    // 3. On value: parseBinaryTelemetry(bytes)
    // 4. On disconnect: _isConnected = false; onDisconnect?.call();
    _isConnected = false;
  }

  /// Parses binary telemetry packet according to specification
  void parseBinaryTelemetry(List<int> bytes) {
    if (bytes.length < 14) return;

    _lastSeq = bytes[0] | (bytes[1] << 8);
    // bytes[2..5] timestamp
    final frontDistance = (bytes[6] | (bytes[7] << 8)).toDouble();
    final downDistance = (bytes[8] | (bytes[9] << 8)).toDouble();

    int readInt16(int offset) {
      final unsigned = bytes[offset] | (bytes[offset + 1] << 8);
      return unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
    }

    final tilt = readInt16(10) / 10.0;
    // bytes[12] flags
    _batteryLevel = bytes[13].clamp(0, 100);
    _isConnected = true;

    if (!_controller.isClosed) {
      _controller.add(
        SensorReading(
          timestamp: DateTime.now(),
          frontDistanceCm: frontDistance,
          downDistanceCm: downDistance,
          pitchAngleDeg: tilt,
          rollAngleDeg: 0.0,
          accelerationMps2: 0.8,
          isCaneConnected: true,
        ),
      );
    }
  }

  void simulateDisconnect() {
    _isConnected = false;
    onDisconnect?.call();
  }

  @override
  Future<void> stop() async {
    _isConnected = false;
  }

  @override
  void dispose() {
    stop();
    _controller.close();
  }
}
