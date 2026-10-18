import 'dart:async';
import '../accessibility/haptic_service.dart';

/// Heartbeat service providing periodic sensory feedback to blind users.
/// During active navigation, emits a subtle haptic tick every 20-25 seconds.
/// If the tick stops, the user immediately knows the app has halted or battery died
/// without ever having to unlock or look at the screen.
class HeartbeatService {
  final HapticService hapticService;
  Duration _interval;
  Timer? _timer;
  bool _isRunning = false;
  bool _isEnabled = true;
  int _ticksEmitted = 0;

  HeartbeatService({
    required this.hapticService,
    Duration this._interval = const Duration(seconds: 25),
    bool this._isEnabled = true,
  });

  bool get isRunning => _isRunning;
  bool get isEnabled => _isEnabled;
  Duration get interval => _interval;
  int get ticksEmitted => _ticksEmitted;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!_isEnabled) {
      _timer?.cancel();
      _timer = null;
    } else if (_isRunning && _timer == null) {
      _startTimer();
    }
  }

  void setInterval(Duration newInterval) {
    _interval = newInterval;
    if (_isRunning && _isEnabled) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void start() {
    _isRunning = true;
    if (_isEnabled) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) async {
      if (_isRunning && _isEnabled) {
        _ticksEmitted++;
        // Subtle haptic pulse confirming app is actively running
        await hapticService.click();
      }
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
