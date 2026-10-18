import 'dart:async';
import '../../voice/intent_matcher.dart';
import '../../voice/voice_session.dart';
import '../../voice/speech_center.dart';
import '../../voice/speech_recognizer_service.dart';
import '../../voice/place_resolver.dart';
import '../../voice/clock.dart';
import '../state/app_state_machine.dart';
import '../navigation/location_query_service.dart';
import '../safety/emergency_beacon_service.dart';

/// Integrates offline voice intent matching and repair ladder into the runtime.
class VoiceAssistant {
  final AppStateMachine stateMachine;
  final VoiceSession voiceSession;

  VoiceAssistant({
    required this.stateMachine,
    required this.voiceSession,
  });

  factory VoiceAssistant.create({
    required AppStateMachine stateMachine,
    required SpeechCenter speechCenter,
    required SpeechRecognizerService recognizer,
    required PlaceResolver placeResolver,
    required IntentMatcher intentMatcher,
    String language = 'en',
    List<String> availablePlaces = const ['bedroom', 'bathroom', 'kitchen', 'door', 'exit'],
    Clock? clock,
    LocationQueryService? locationQueryService,
    EmergencyBeaconService? emergencyBeaconService,
  }) {
    late final VoiceSession session;

    session = VoiceSession(
      speechCenter: speechCenter,
      recognizer: recognizer,
      language: language,
      availablePlaces: availablePlaces,
      placeResolver: placeResolver,
      clock: clock ?? RealClock(),
      onIntentMatched: (intent, place) {
        switch (intent) {
          case Intent.startNavigation:
            if (place != null) {
              stateMachine.handleEvent(
                StartNavigationEvent(destinationId: place, destinationName: place),
              );
            }
            break;
          case Intent.stopNavigation:
            stateMachine.handleEvent(const RecoverToIdleEvent());
            break;
          case Intent.sendHelp:
            emergencyBeaconService?.startEmergencyBeacon();
            stateMachine.handleEvent(
              const SystemErrorEvent(
                errorMessage: 'Emergency SOS triggered by voice',
                canAutoRecover: false,
              ),
            );
            break;
          case Intent.whereAmI:
            if (locationQueryService != null) {
              locationQueryService.getLocationReport().then((r) {
                speechCenter.speak(r.spokenSummary);
              });
            } else {
              speechCenter.speak('You are currently near the central corridor.');
            }
            break;
          default:
            break;
        }
      },
    );

    return VoiceAssistant(stateMachine: stateMachine, voiceSession: session);
  }

  Future<void> triggerVoiceCommand() async {
    await stateMachine.handleEvent(const StartListeningEvent());
    await voiceSession.start();
  }

  void cancelVoiceCommand() {
    voiceSession.cancel();
    stateMachine.handleEvent(const StopListeningEvent());
  }

  void dispose() {
    voiceSession.dispose();
  }
}
