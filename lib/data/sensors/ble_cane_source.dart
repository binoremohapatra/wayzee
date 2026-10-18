import 'dart:async';
import '../../domain/fusion/sensor_source.dart';

/// Bluetooth Low Energy Smart Cane source stub.
/// Documented GATT Profile for future ESP32-S3 cane hardware integration:
/// Service UUID: 0000FFE0-0000-1000-8000-00805F9B34FB (Wayze Cane Telemetry)
/// Characteristic UUID: 0000FFE1-0000-1000-8000-00805F9B34FB (ToF + IMU Packet, Notify)
///
/// Packet Format (14 Bytes Little-Endian):
/// [0..1] uint16: frontDistanceCm
/// [2..3] uint16: downDistanceCm
/// [4..5] int16: pitchAngle (deg * 10)
/// [6..7] int16: rollAngle (deg * 10)
/// [8..9] int16: accelX (m/s^2 * 100)
/// [10..11] int16: accelY (m/s^2 * 100)
/// [12..13] int16: accelZ (m/s^2 * 100)
class BleCaneSource implements SensorSource {
  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  bool _isConnected = false;

  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  bool get isConnected => _isConnected;

  @override
  Future<void> start() async {
    // When real BLE hardware is bonded:
    // 1. Scan for serviceUuid
    // 2. Connect and subscribe to characteristicUuid notifications
    // 3. In onValueReceived: parseBinaryTelemetry(bytes)
    _isConnected = false;
  }

  /// Parses 14-byte binary payload from ESP32 ToF & MPU6050 cane sensors.
  void parseBinaryTelemetry(List<int> bytes) {
    if (bytes.length < 14) return;

    final frontDistance = (bytes[0] | (bytes[1] << 8)).toDouble();
    final downDistance = (bytes[2] | (bytes[3] << 8)).toDouble();

    int readInt16(int offset) {
      final unsigned = bytes[offset] | (bytes[offset + 1] << 8);
      return unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
    }

    final pitch = readInt16(4) / 10.0;
    final roll = readInt16(6) / 10.0;
    final accelX = readInt16(8) / 100.0;
    final accelY = readInt16(10) / 100.0;
    final accelZ = readInt16(12) / 100.0;

    final netAccel = (accelX * accelX + accelY * accelY + accelZ * accelZ);

    if (!_controller.isClosed) {
      _controller.add(
        SensorReading(
          timestamp: DateTime.now(),
          frontDistanceCm: frontDistance,
          downDistanceCm: downDistance,
          pitchAngleDeg: pitch,
          rollAngleDeg: roll,
          accelerationMps2: netAccel,
          isCaneConnected: true,
        ),
      );
    }
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
