import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state_machine.dart';

/// Manages crash-loop protection: 3 crashes within 5 minutes triggers SAFE MODE.
/// In Safe Mode, heavy delegates (camera, neural network, voice recognizer) are disabled.
/// Only vibration patterns, sensor telemetry, and a single tactile emergency button remain.
class SafeModeManager {
  static const String keyCrashTimestamps = 'wayze_recent_crash_timestamps';
  static const int maxCrashesAllowed = 3;
  static const int crashWindowSeconds = 300; // 5 minutes

  final SharedPreferences prefs;
  final AppStateMachine stateMachine;

  SafeModeManager({required this.prefs, required this.stateMachine});

  /// Called upon application start to log this session start.
  /// If previous 2 sessions started less than 5 minutes ago and crashed, enter Safe Mode.
  Future<bool> evaluateStartupSafety({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final nowEpoch = currentTime.millisecondsSinceEpoch;

    final rawList = prefs.getStringList(keyCrashTimestamps) ?? [];
    final windowStart = nowEpoch - (crashWindowSeconds * 1000);

    // Keep only timestamps within last 5 minutes
    final activeTimestamps = rawList
        .map((s) => int.tryParse(s) ?? 0)
        .where((ts) => ts >= windowStart)
        .toList();

    activeTimestamps.add(nowEpoch);
    await prefs.setStringList(
      keyCrashTimestamps,
      activeTimestamps.map((ts) => ts.toString()).toList(),
    );

    if (activeTimestamps.length >= maxCrashesAllowed) {
      await stateMachine.handleEvent(
        const EnterSafeModeEvent('3 crashes in 5 minutes detected'),
      );
      return true;
    }

    return false;
  }

  /// Called after 60 seconds of stable operation to clear crash history
  Future<void> markSessionStable() async {
    await prefs.remove(keyCrashTimestamps);
  }

  Future<void> resetSafeMode() async {
    await markSessionStable();
    await stateMachine.handleEvent(const ExitSafeModeEvent());
  }
}
