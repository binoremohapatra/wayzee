import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/core/reliability/thermal_governor.dart';
import 'package:wayze/data/tts_stt/tts_service.dart';
import 'package:wayze/data/vision/native_vision_bridge.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/fusion/fusion_engine.dart';
import 'package:wayze/domain/fusion/sensor_source.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/safety/fallback_coordinator.dart';
import 'package:wayze/domain/safety/safe_mode_manager.dart';
import 'package:wayze/domain/safety/camera_health_monitor.dart';
import 'package:wayze/domain/state/app_state_machine.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';

class MockVisionBridge implements VisionBridge {
  bool isVisionRunning = true;
  bool isStationarySet = false;
  int mockThermalStatus = 0;

  @override
  Future<bool> startForegroundService() async => true;

  @override
  Future<bool> stopForegroundService() async => true;

  @override
  Future<bool> startVision() async {
    isVisionRunning = true;
    return true;
  }

  @override
  Future<bool> stopVision() async {
    isVisionRunning = false;
    return true;
  }

  @override
  Future<void> setStationary(bool isStationary) async {
    isStationarySet = isStationary;
  }

  @override
  Future<int> getThermalStatus() async => mockThermalStatus;

  @override
  Stream<String> get hardwareKeyStream => const Stream.empty();

  @override
  Stream<List<VisionDetection>> get visionStream => const Stream.empty();

  @override
  Stream<CameraFrameHealth> get cameraHealthStream => const Stream.empty();
}

void main() {
  group('Comprehensive Safety, Reliability and Fallback Matrix Tests', () {
    late MockTtsService tts;
    late MockHapticService haptics;
    late MockVisionBridge visionBridge;
    late AppStateMachine stateMachine;
    late FallbackCoordinator fallbackCoordinator;
    late AlertQueue alertQueue;
    late FusionEngine fusionEngine;

    setUp(() {
      tts = MockTtsService();
      haptics = MockHapticService();
      visionBridge = MockVisionBridge();
      stateMachine = AppStateMachine(ttsService: tts);
      fallbackCoordinator = FallbackCoordinator(
        ttsService: tts,
        hapticService: haptics,
        visionBridge: visionBridge,
        stateMachine: stateMachine,
      );
      alertQueue = AlertQueue();
      fusionEngine = FusionEngine(
        alertQueue: alertQueue,
        visionTracker: VisionTracker(),
        hapticService: haptics,
      );
    });

    test('1. Unknown room: announces unmapped area and keeps live obstacle alerts', () {
      fusionEngine.announceUnknownRoom();
      final alert = alertQueue.dequeue();
      expect(alert, isNotNull);
      expect(alert!.speechText, equals('No map for this room. Live obstacle alerts active.'));
      expect(alert.priority, equals(AlertPriority.p1Navigation));
    });

    test('2. Darkness: camera sees nothing, physical sensors provide safe zero-false-alarm baseline', () {
      final t = DateTime.now();
      // Zero camera detections in the dark
      final confirmed = fusionEngine.ingestVisionDetections([], now: t);
      expect(confirmed, isEmpty);

      // Normal sensor walk
      fusionEngine.ingestSensorReading(
        SensorReading(timestamp: t, frontDistanceCm: 250.0, downDistanceCm: 110.0),
      );
      expect(alertQueue.dequeue(), isNull);
    });

    test('3. Glass door: camera misses transparent barrier, cane ultrasonic/ToF catches <50cm', () {
      final t1 = DateTime.now();
      final t2 = t1.add(const Duration(milliseconds: 100));

      // Camera sees clear (no detections)
      fusionEngine.ingestVisionDetections([], now: t1);

      // Smart cane detects physical surface at 38cm
      fusionEngine.ingestSensorReading(
        SensorReading(timestamp: t1, frontDistanceCm: 38.0, downDistanceCm: 110.0, isCaneConnected: true),
      );
      fusionEngine.ingestSensorReading(
        SensorReading(timestamp: t2, frontDistanceCm: 35.0, downDistanceCm: 110.0, isCaneConnected: true),
      );

      final p0Alert = alertQueue.dequeue();
      expect(p0Alert, isNotNull);
      expect(p0Alert!.priority, equals(AlertPriority.p0Danger));
      expect(p0Alert.speechText, equals('Obstacle directly ahead. Stop.'));
      expect(haptics.triggerHistory, contains(HapticPattern.danger));
    });

    test('4. BLE Cane lost: triggers warning haptic, announces switch to phone-only mode', () async {
      await fallbackCoordinator.handleBleDisconnection();
      expect(haptics.triggerHistory, contains(HapticPattern.warning));
      expect(tts.spokenUtterances.last, equals('Cane disconnected. Switched to phone-only mode.'));
    });

    test('5. Vision crash: restarts up to 3 times, then permanently falls back to sensor+map mode', () async {
      // Crashes 1 to 3: restarts
      for (int i = 1; i <= 3; i++) {
        await fallbackCoordinator.handleCameraFailure();
        expect(tts.spokenUtterances.last, contains('Attempting restart $i of 3'));
        expect(fallbackCoordinator.isVisionPermanentlyDisabled, isFalse);
      }

      // Crash 4: disables vision and falls back
      await fallbackCoordinator.handleCameraFailure();
      expect(fallbackCoordinator.isVisionPermanentlyDisabled, isTrue);
      expect(visionBridge.isVisionRunning, isFalse);
      expect(tts.spokenUtterances.last, equals('Camera unavailable. Switched to smart cane and map mode.'));
    });

    test('6. Thermal rise: severe thermal state scales FPS down and speaks warning', () async {
      final governor = ThermalGovernor(visionBridge: visionBridge, ttsService: tts);
      visionBridge.mockThermalStatus = 3; // Severe

      await governor.checkThermalStatus();
      expect(visionBridge.isStationarySet, isTrue); // Lower FPS throttled
      expect(tts.spokenUtterances.last, contains('Phone temperature high. Reducing visual frame rate.'));
    });

    test('7. TTS failure: tactile vibration patterns communicate P0 and P1 alerts', () async {
      haptics.clear();
      await fallbackCoordinator.handleTtsFailure(AlertPriority.p0Danger);
      expect(haptics.triggerHistory, contains(HapticPattern.danger));

      haptics.clear();
      await fallbackCoordinator.handleTtsFailure(AlertPriority.p1Navigation);
      expect(haptics.triggerHistory, contains(HapticPattern.warning));

      haptics.clear();
      await fallbackCoordinator.handleTtsFailure(AlertPriority.p2Info);
      expect(haptics.triggerHistory, contains(HapticPattern.click));
    });

    test('8. 3 crashes in 5 minutes triggers SAFE MODE', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final safeModeManager = SafeModeManager(prefs: prefs, stateMachine: stateMachine);

      final now = DateTime.now();
      expect(await safeModeManager.evaluateStartupSafety(now: now), isFalse);
      expect(await safeModeManager.evaluateStartupSafety(now: now.add(const Duration(seconds: 10))), isFalse);

      // Third crash within 5 minutes
      final triggered = await safeModeManager.evaluateStartupSafety(now: now.add(const Duration(seconds: 20)));
      expect(triggered, isTrue);
      expect(stateMachine.currentState, equals(WayzeState.safeMode));
      expect(tts.spokenUtterances.last, equals('Wayze is in safe mode. Use your cane.'));
    });
  });
}
