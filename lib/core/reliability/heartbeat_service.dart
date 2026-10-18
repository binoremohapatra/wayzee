import 'dart:async';
import '../accessibility/haptic_service.dart';

/// Heartbeat service providing periodic sensory feedback to blind users.
/// During active navigation, emits a subtle haptic tick every 20-25 seconds.
/// If the tick stops, the user immediately knows the app has halted or battery died
/// without ever having to unlock or look at the screen.
class HeartbeatService {
  final HapticService hapticService;
  final Duration interval;
  Timer? _timer;
  bool _isRunning = false;

  HeartbeatService({
    required this.hapticService,
    this.interval = const Duration(seconds: 25),
  });

  bool get isRunning => _isRunning;

  void start() {
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      if (_isRunning) {
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
