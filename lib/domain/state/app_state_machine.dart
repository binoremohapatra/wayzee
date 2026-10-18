import 'dart:async';
import '../models/alert_item.dart';
import '../../data/tts_stt/tts_service.dart';

/// Explicit application states for the Wayze runtime.
enum WayzeState {
  idle,
  listening,
  navigating,
  alerting,
  paused,
  error;

  String get spokenName {
    switch (this) {
      case WayzeState.idle:
        return 'Wayze is ready';
      case WayzeState.listening:
        return 'Listening for command';
      case WayzeState.navigating:
        return 'Navigation active';
      case WayzeState.alerting:
        return 'Hazard alert';
      case WayzeState.paused:
        return 'Guidance paused';
      case WayzeState.error:
        return 'System error';
    }
  }
}

/// Events that drive state transitions.
abstract class WayzeEvent {
  const WayzeEvent();
}

class StartListeningEvent extends WayzeEvent {
  const StartListeningEvent();
}

class StopListeningEvent extends WayzeEvent {
  final String? recognizedText;
  const StopListeningEvent([this.recognizedText]);
}

class StartNavigationEvent extends WayzeEvent {
  final String destinationId;
  final String destinationName;
  const StartNavigationEvent({required this.destinationId, required this.destinationName});
}

class ObstacleAlertEvent extends WayzeEvent {
  final AlertItem alert;
  const ObstacleAlertEvent(this.alert);
}

class AlertResolvedEvent extends WayzeEvent {
  const AlertResolvedEvent();
}

class PauseGuidanceEvent extends WayzeEvent {
  final String reason;
  const PauseGuidanceEvent([this.reason = 'Guidance paused by user']);
}

class ResumeGuidanceEvent extends WayzeEvent {
  const ResumeGuidanceEvent();
}

class SystemErrorEvent extends WayzeEvent {
  final String errorMessage;
  final bool canAutoRecover;
  const SystemErrorEvent({required this.errorMessage, this.canAutoRecover = true});
}

class RecoverToIdleEvent extends WayzeEvent {
  const RecoverToIdleEvent();
}

/// Deterministic, production state machine for Wayze.
/// Every state has a recovery path; errors are spoken to the user, never silent.
class AppStateMachine {
  final TtsService _ttsService;
  final StreamController<WayzeState> _stateController =
      StreamController<WayzeState>.broadcast();

  WayzeState _currentState = WayzeState.idle;
  WayzeState _stateBeforeAlert = WayzeState.idle;
  String? _lastErrorMessage;

  AppStateMachine({required TtsService ttsService}) : _ttsService = ttsService;

  WayzeState get currentState => _currentState;
  String? get lastErrorMessage => _lastErrorMessage;
  Stream<WayzeState> get stateStream => _stateController.stream;

  /// Process an event and transition states. Spoken feedback is issued on errors.
  Future<void> handleEvent(WayzeEvent event) async {
    final previous = _currentState;

    if (event is SystemErrorEvent) {
      _lastErrorMessage = event.errorMessage;
      _transitionTo(WayzeState.error);
      // Errors are spoken to the user, never silent.
      await _ttsService.speak(
        'Warning: ${event.errorMessage}. Please wait while Wayze recovers.',
        priority: AlertPriority.p0Danger,
      );
      if (event.canAutoRecover) {
        // Auto recovery attempt after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentState == WayzeState.error) {
            handleEvent(const RecoverToIdleEvent());
          }
        });
      }
      return;
    }

    switch (_currentState) {
      case WayzeState.idle:
        if (event is StartListeningEvent) {
          _transitionTo(WayzeState.listening);
        } else if (event is StartNavigationEvent) {
          _transitionTo(WayzeState.navigating);
          await _ttsService.speak(
            'Starting route to ${event.destinationName}. Follow spoken steps.',
            priority: AlertPriority.p1Navigation,
          );
        }
        break;

      case WayzeState.listening:
        if (event is StopListeningEvent) {
          _transitionTo(WayzeState.idle);
        } else if (event is StartNavigationEvent) {
          _transitionTo(WayzeState.navigating);
          await _ttsService.speak(
            'Starting route to ${event.destinationName}.',
            priority: AlertPriority.p1Navigation,
          );
        } else if (event is ObstacleAlertEvent && event.alert.priority == AlertPriority.p0Danger) {
          _stateBeforeAlert = WayzeState.idle;
          _transitionTo(WayzeState.alerting);
        }
        break;

      case WayzeState.navigating:
        if (event is ObstacleAlertEvent) {
          _stateBeforeAlert = WayzeState.navigating;
          _transitionTo(WayzeState.alerting);
        } else if (event is PauseGuidanceEvent) {
          _transitionTo(WayzeState.paused);
          await _ttsService.speak(
            event.reason,
            priority: AlertPriority.p1Navigation,
          );
        } else if (event is StartListeningEvent) {
          _transitionTo(WayzeState.listening);
        } else if (event is RecoverToIdleEvent) {
          _transitionTo(WayzeState.idle);
          await _ttsService.speak(
            'Navigation ended. Standing by.',
            priority: AlertPriority.p1Navigation,
          );
        }
        break;

      case WayzeState.alerting:
        if (event is AlertResolvedEvent) {
          // Return to prior state
          _transitionTo(_stateBeforeAlert == WayzeState.navigating
              ? WayzeState.navigating
              : WayzeState.idle);
        } else if (event is ObstacleAlertEvent && event.alert.priority == AlertPriority.p0Danger) {
          // Stay alerting for new danger
          _transitionTo(WayzeState.alerting);
        } else if (event is PauseGuidanceEvent) {
          _transitionTo(WayzeState.paused);
        }
        break;

      case WayzeState.paused:
        if (event is ResumeGuidanceEvent) {
          _transitionTo(WayzeState.navigating);
          await _ttsService.speak(
            'Resuming guidance.',
            priority: AlertPriority.p1Navigation,
          );
        } else if (event is RecoverToIdleEvent) {
          _transitionTo(WayzeState.idle);
          await _ttsService.speak(
            'Guidance stopped.',
            priority: AlertPriority.p1Navigation,
          );
        } else if (event is StartListeningEvent) {
          _transitionTo(WayzeState.listening);
        }
        break;

      case WayzeState.error:
        if (event is RecoverToIdleEvent || event is ResumeGuidanceEvent) {
          _transitionTo(WayzeState.idle);
          await _ttsService.speak(
            'Wayze recovered. Ready.',
            priority: AlertPriority.p2Info,
          );
        }
        break;
    }
  }

  void _transitionTo(WayzeState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(_currentState);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
