import 'dart:async';
import '../../voice/intent_matcher.dart';
import '../../voice/voice_session.dart';
import '../../voice/speech_center.dart';
import '../../voice/speech_recognizer_service.dart';
import '../../voice/place_resolver.dart';
import '../../voice/clock.dart';
import '../state/app_state_machine.dart';

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
    Clock clock = const SystemClock(),
  }) {
    late final VoiceSession session;

    session = VoiceSession(
      speech: speechCenter,
      recognizer: recognizer,
      places: placeResolver,
      matcher: intentMatcher,
      clock: clock,
      onNavigate: (place) {
        stateMachine.handleEvent(
          StartNavigationEvent(destinationId: place, destinationName: place),
        );
      },
      onStop: () {
        stateMachine.handleEvent(const RecoverToIdleEvent());
      },
      onSendHelp: () {
        stateMachine.handleEvent(
          const SystemErrorEvent(errorMessage: 'Emergency SOS triggered by voice', canAutoRecover: false),
        );
      },
      onWhereAmI: () {
        speechCenter.speak('You are currently near the central corridor.');
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
