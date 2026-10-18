import 'dart:async';
import '../../data/tts_stt/tts_service.dart';
import '../../core/accessibility/haptic_service.dart';

/// Service managing emergency SOS acoustic siren and synchronized tactile beacon.
/// When triggered (by fall detection or manual SOS), pulses an urgent acoustic tone
/// and repeated vibration pulses so sighted bystanders and emergency responders
/// can quickly locate the user.
class EmergencyBeaconService {
  final TtsService ttsService;
  final HapticService hapticService;

  bool _isBeaconActive = false;
  Timer? _beaconLoopTimer;
  int _pulseCount = 0;

  EmergencyBeaconService({
    required this.ttsService,
    required this.hapticService,
  });

  bool get isBeaconActive => _isBeaconActive;
  int get pulseCount => _pulseCount;

  /// Activates the loud SOS acoustic siren and vibration beacon loop.
  Future<void> startEmergencyBeacon({String emergencyMessage = 'Emergency assistance requested. User needs help.'}) async {
    if (_isBeaconActive) return;

    _isBeaconActive = true;
    _pulseCount = 0;

    // Immediate initial alarm sound and speech
    await _pulseBeacon(emergencyMessage);

    // Periodic repeating pulsing loop (every 3.5 seconds)
    _beaconLoopTimer?.cancel();
    _beaconLoopTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (_isBeaconActive) {
        _pulseBeacon(emergencyMessage);
      }
    });
  }

  Future<void> _pulseBeacon(String message) async {
    _pulseCount++;
    // 1. High-priority tactile SOS Morse pulse
    await hapticService.danger();

    // 2. High-priority spoken assistance alert
    await ttsService.speak('Emergency! Help needed here! $message');
  }

  /// Silences the emergency beacon with reassuring audio feedback.
  Future<void> stopEmergencyBeacon() async {
    if (!_isBeaconActive) return;

    _isBeaconActive = false;
    _beaconLoopTimer?.cancel();
    _beaconLoopTimer = null;

    await hapticService.confirm();
    await ttsService.speak('Emergency beacon silenced.');
  }

  void dispose() {
    _beaconLoopTimer?.cancel();
    _beaconLoopTimer = null;
    _isBeaconActive = false;
  }
}
