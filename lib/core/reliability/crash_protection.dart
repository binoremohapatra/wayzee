import 'package:shared_preferences/shared_preferences.dart';

/// Protects against startup crash loops.
/// If app terminates abnormally multiple times within 60 seconds of startup,
/// safe mode is enabled to prevent permanent lockout of visually impaired users.
class CrashProtection {
  static const String keyCrashCount = 'wayze_crash_loop_count';
  static const String keyLastStartup = 'wayze_last_startup_timestamp';

  final SharedPreferences prefs;

  CrashProtection(this.prefs);

  Future<bool> checkAndRecordStartup() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastStartup = prefs.getInt(keyLastStartup) ?? 0;
    int crashCount = prefs.getInt(keyCrashCount) ?? 0;

    // If last startup was less than 60 seconds ago without a clean exit, treat as abnormal termination
    if (now - lastStartup < 60000 && lastStartup > 0) {
      crashCount++;
    } else {
      crashCount = 1;
    }

    await prefs.setInt(keyLastStartup, now);
    await prefs.setInt(keyCrashCount, crashCount);

    return crashCount >= 3; // Trigger safe mode if 3 rapid crashes detected
  }

  Future<void> recordCleanExit() async {
    await prefs.setInt(keyCrashCount, 0);
    await prefs.setInt(keyLastStartup, 0);
  }
}
