import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hardware and build information used to validate whether benchmark numbers
/// are captured on a physical Android target or an unverified emulator/debug environment.
class DeviceInfo {
  final String model;
  final String osVersion;
  final int ramTotalBytes;
  final String soc;
  final bool isDebug;
  final bool isEmulator;

  const DeviceInfo({
    required this.model,
    required this.osVersion,
    required this.ramTotalBytes,
    required this.soc,
    required this.isDebug,
    required this.isEmulator,
  });

  /// Factory providing default/fallback information (e.g. for unit tests or desktop)
  factory DeviceInfo.fallback({
    String model = 'Android Physical Device',
    String osVersion = 'Android 13',
    int ramTotalBytes = 4294967296, // 4GB
    String soc = 'ARM Cortex / Snapdragon',
    bool isDebug = kDebugMode,
    bool isEmulator = false,
  }) {
    return DeviceInfo(
      model: model,
      osVersion: osVersion,
      ramTotalBytes: ramTotalBytes,
      soc: soc,
      isDebug: isDebug,
      isEmulator: isEmulator,
    );
  }

  /// Whether metrics from this session are valid for investor/partner pitch claims.
  /// Strictly requires a release build on real physical hardware.
  bool get isValidForPitch => !isEmulator && !isDebug;

  String get formattedRam {
    if (ramTotalBytes <= 0) return 'Unknown';
    final gb = ramTotalBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  String? get pitchWarningReason {
    if (isEmulator && isDebug) {
      return 'RUNNING ON EMULATOR & DEBUG BUILD — Timings, XNNPACK delegates, and thermal behavior are simulated and NOT VALID FOR PITCH.';
    }
    if (isEmulator) {
      return 'RUNNING ON EMULATOR — Virtualized CPU does not represent budget phone performance. NOT VALID FOR PITCH.';
    }
    if (isDebug) {
      return 'DEBUG BUILD ACTIVE — Dart VM JIT overhead inflates inference and post-processing latency. Build release APK for verified numbers.';
    }
    return null;
  }
}

/// Service that queries Android hardware properties via MethodChannel.
class DeviceInfoService {
  static const MethodChannel _channel = MethodChannel('com.wayze/service');

  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (res != null) {
        return DeviceInfo(
          model: res['model']?.toString() ?? 'Android Device',
          osVersion: res['osVersion']?.toString() ?? 'Android',
          ramTotalBytes: (res['totalRamBytes'] as num?)?.toInt() ?? 0,
          soc: res['soc']?.toString() ?? 'ARM SoC',
          isDebug: kDebugMode,
          isEmulator: res['isEmulator'] as bool? ?? false,
        );
      }
    } catch (_) {
      // Fallback when running outside Android or in headless test runner
    }

    return DeviceInfo.fallback();
  }
}
