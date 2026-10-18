import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/core/reliability/heartbeat_service.dart';
import 'package:wayze/data/tts_stt/tts_service.dart';
import 'package:wayze/data/vision/native_vision_bridge.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/fusion/fusion_engine.dart';
import 'package:wayze/domain/fusion/sensor_source.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/models/spatial_zone.dart';
import 'package:wayze/domain/safety/camera_health_monitor.dart';
import 'package:wayze/domain/safety/safe_mode_manager.dart';
import 'package:wayze/domain/state/app_state_machine.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';

void main() {
  group('Phase 1: Safety & Reliability Tests', () {
    late AlertQueue alertQueue;
    late VisionTracker tracker;
    late MockHapticService mockHaptics;
    late FusionEngine engine;

    setUp(() {
      alertQueue = AlertQueue();
      tracker = VisionTracker(
        iouMatchThreshold: 0.35,
        minConfirmingFrames: 2,
        alphaSmoothing: 0.30,
        perClassConfidenceThresholds: {
          'stairs_down': 0.70,
          'stairs_up': 0.65,
          'stairs': 0.70,
          'drop_off': 0.70,
          'obstacle': 0.45,
          'person': 0.50,
        },
      );
      mockHaptics = MockHapticService();
      engine = FusionEngine(
        alertQueue: alertQueue,
        visionTracker: tracker,
        hapticService: mockHaptics,
        expectedDownDistanceCm: 110.0,
        dropOffThresholdCm: 35.0,
        frontObstacleThresholdCm: 50.0,
        stairsConfirmationWindow: const Duration(milliseconds: 1500),
        imuPitchChangeThresholdDeg: 10.0,
      );
    });

    test('Per-class confidence thresholds: stairs requires 0.70, lower confidence is rejected', () {
      const lowConfStairs = VisionDetection(
        label: 'stairs_down',
        confidence: 0.62, // Below 0.70
        zone: SpatialZone.center,
        boxArea: 0.20,
        bottomY: 0.75,
        timestamp: 1000,
      );

      final alerts = tracker.processDetections([lowConfStairs], nowMs: 1000);
      expect(alerts, isEmpty);
      expect(tracker.activeTracks, isEmpty);

      const highConfStairs = VisionDetection(
        label: 'stairs_down',
        confidence: 0.75, // Above 0.70
        zone: SpatialZone.center,
        boxArea: 0.20,
        bottomY: 0.75,
        timestamp: 1100,
      );

      tracker.processDetections([highConfStairs], nowMs: 1100);
      expect(tracker.activeTracks.length, equals(1));
    });

    test('Single-frame spike must not alert (temporal confirmation suppresses false positive)', () {
      const singleSpike = VisionDetection(
        label: 'stairs_down',
        confidence: 0.85,
        zone: SpatialZone.center,
        boxArea: 0.20,
        bottomY: 0.75,
        timestamp: 1000,
      );

      // Only 1 frame provided
      final alerts = engine.ingestVisionDetections([singleSpike], now: DateTime.fromMillisecondsSinceEpoch(1000));
      expect(alerts, isEmpty);
      expect(alertQueue.isEmpty, isTrue);
    });

    test('Stairs two-stage confirmation: camera-only stairs detection emits hedged P1', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1100);

      const d1 = VisionDetection(label: 'stairs_down', confidence: 0.85, zone: SpatialZone.center, boxArea: 0.20, bottomY: 0.75, timestamp: 1000);
      const d2 = VisionDetection(label: 'stairs_down', confidence: 0.88, zone: SpatialZone.center, boxArea: 0.22, bottomY: 0.78, timestamp: 1100);

      engine.ingestVisionDetections([d1], now: t1);
      engine.ingestVisionDetections([d2], now: t2);

      final alert = alertQueue.dequeue(now: t2);
      expect(alert, isNotNull);
      expect(alert!.priority, equals(AlertPriority.p1Navigation));
      expect(alert.speechText, equals('Maybe stairs ahead, slow down.'));
      // No P0 danger haptics for hedged alert
      expect(mockHaptics.triggerHistory.contains(HapticPattern.danger), isFalse);
    });

    test('Stairs two-stage confirmation: Camera stairs + cane down-range spike within window -> confirmed P0 Stop', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1100);
      final tSpike = DateTime.fromMillisecondsSinceEpoch(1400); // 300ms later, within 1500ms window

      const d1 = VisionDetection(label: 'stairs_down', confidence: 0.85, zone: SpatialZone.center, boxArea: 0.20, bottomY: 0.75, timestamp: 1000);
      const d2 = VisionDetection(label: 'stairs_down', confidence: 0.88, zone: SpatialZone.center, boxArea: 0.22, bottomY: 0.78, timestamp: 1100);

      engine.ingestVisionDetections([d1], now: t1);
      engine.ingestVisionDetections([d2], now: t2);

      // Now Cane detects down-range spike
      final caneReading = SensorReading(
        timestamp: tSpike,
        frontDistanceCm: 200.0,
        downDistanceCm: 160.0, // > 110 + 35 = 145cm spike
        isCaneConnected: true,
      );
      engine.ingestSensorReading(caneReading);

      final p0Alert = alertQueue.dequeue(now: tSpike);
      expect(p0Alert, isNotNull);
      expect(p0Alert!.priority, equals(AlertPriority.p0Danger));
      expect(p0Alert.speechText, equals('Stairs ahead. Stop.'));
      expect(mockHaptics.triggerHistory, contains(HapticPattern.danger));
    });

    test('Stairs two-stage confirmation: Camera stairs + IMU tilt change within window -> confirmed P0 Stop', () {
      final tInit = DateTime.fromMillisecondsSinceEpoch(500);
      final t1 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1100);
      final tImuChange = DateTime.fromMillisecondsSinceEpoch(1300); // within 1500ms

      // Initialize baseline pitch at 5.0 deg
      engine.ingestSensorReading(SensorReading(
        timestamp: tInit,
        frontDistanceCm: 200.0,
        downDistanceCm: 110.0,
        pitchAngleDeg: 5.0,
      ));

      // Camera detects stairs
      const d1 = VisionDetection(label: 'stairs_down', confidence: 0.85, zone: SpatialZone.center, boxArea: 0.20, bottomY: 0.75, timestamp: 1000);
      const d2 = VisionDetection(label: 'stairs_down', confidence: 0.88, zone: SpatialZone.center, boxArea: 0.22, bottomY: 0.78, timestamp: 1100);
      engine.ingestVisionDetections([d1], now: t1);
      engine.ingestVisionDetections([d2], now: t2);

      // User tilts phone as they approach stairs edge (pitch shifts from 5.0 to 18.0 deg, delta = 13.0 > 10.0 threshold)
      engine.ingestSensorReading(SensorReading(
        timestamp: tImuChange,
        frontDistanceCm: 200.0,
        downDistanceCm: 110.0,
        pitchAngleDeg: 18.0,
      ));

      final p0Alert = alertQueue.dequeue(now: tImuChange);
      expect(p0Alert, isNotNull);
      expect(p0Alert!.priority, equals(AlertPriority.p0Danger));
      expect(p0Alert.speechText, equals('Stairs ahead. Stop.'));
      expect(mockHaptics.triggerHistory, contains(HapticPattern.danger));
    });

    test('CameraHealthMonitor: low-light requires >=2 consecutive frames, debounces cooldown', () {
      final monitorQueue = AlertQueue();
      final monitor = CameraHealthMonitor(
        alertQueue: monitorQueue,
        cooldown: const Duration(seconds: 20),
        minConsecutiveFrames: 2,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t1 = DateTime.fromMillisecondsSinceEpoch(1100);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1200);
      final tAfterCooldown = t0.add(const Duration(seconds: 22));

      // Frame 1: dark (single frame spike should NOT alert)
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 10.0, varianceLuminance: 12.0, isDark: true, isBlocked: false, timestamp: t0),
        pitchAngleDeg: 0.0,
        now: t0,
      );
      expect(monitorQueue.isEmpty, isTrue);

      // Frame 2: consecutive dark -> alerts
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 9.0, varianceLuminance: 10.0, isDark: true, isBlocked: false, timestamp: t1),
        pitchAngleDeg: 0.0,
        now: t1,
      );
      expect(monitorQueue.length, equals(1));
      final alert1 = monitorQueue.dequeue(now: t1);
      expect(alert1!.speechText, equals('Camera cannot see well, rely on your cane.'));

      // Frame 3 within cooldown: must NOT spam alert
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 8.0, varianceLuminance: 10.0, isDark: true, isBlocked: false, timestamp: t2),
        pitchAngleDeg: 0.0,
        now: t2,
      );
      expect(monitorQueue.isEmpty, isTrue);

      // Frame after 22s cooldown: alerts again
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 8.0, varianceLuminance: 10.0, isDark: true, isBlocked: false, timestamp: tAfterCooldown),
        pitchAngleDeg: 0.0,
        now: tAfterCooldown,
      );
      expect(monitorQueue.length, equals(1));
      expect(monitorQueue.dequeue(now: tAfterCooldown)!.speechText, equals('Camera cannot see well, rely on your cane.'));
    });

    test('CameraHealthMonitor: blocked camera requires >=2 consecutive frames and debounces', () {
      final monitorQueue = AlertQueue();
      final monitor = CameraHealthMonitor(
        alertQueue: monitorQueue,
        cooldown: const Duration(seconds: 20),
        minConsecutiveFrames: 2,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t1 = DateTime.fromMillisecondsSinceEpoch(1100);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1200);

      // Frame 1: blocked
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 30.0, varianceLuminance: 2.0, isDark: false, isBlocked: true, timestamp: t0),
        pitchAngleDeg: 0.0,
        now: t0,
      );
      expect(monitorQueue.isEmpty, isTrue);

      // Frame 2: consecutive blocked -> alerts
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 30.0, varianceLuminance: 2.0, isDark: false, isBlocked: true, timestamp: t1),
        pitchAngleDeg: 0.0,
        now: t1,
      );
      expect(monitorQueue.length, equals(1));
      expect(monitorQueue.dequeue(now: t1)!.speechText, equals('Camera is blocked.'));

      // Frame 3 within cooldown: no duplicate spam
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 30.0, varianceLuminance: 2.0, isDark: false, isBlocked: true, timestamp: t2),
        pitchAngleDeg: 0.0,
        now: t2,
      );
      expect(monitorQueue.isEmpty, isTrue);
    });

    test('CameraHealthMonitor: phone in pocket / bad angle emits "Place phone on your chest."', () {
      final monitorQueue = AlertQueue();
      final monitor = CameraHealthMonitor(
        alertQueue: monitorQueue,
        cooldown: const Duration(seconds: 20),
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

      // Pitch angle is -75 degrees (phone tilted down into pocket) and dark
      monitor.evaluateFrame(
        frameHealth: CameraFrameHealth(meanLuminance: 5.0, varianceLuminance: 2.0, isDark: true, isBlocked: true, timestamp: t0),
        pitchAngleDeg: -75.0,
        now: t0,
      );

      expect(monitorQueue.length, equals(1));
      final alert = monitorQueue.dequeue(now: t0);
      expect(alert!.speechText, equals('Place phone on your chest.'));
    });

    test('HeartbeatService: periodic ticks, enable/disable toggle, and interval adjustment', () async {
      final testHaptics = MockHapticService();
      final heartbeat = HeartbeatService(
        hapticService: testHaptics,
        interval: const Duration(milliseconds: 50),
        isEnabled: true,
      );

      expect(heartbeat.isEnabled, isTrue);
      heartbeat.start();
      expect(heartbeat.isRunning, isTrue);

      // Wait for tick
      await Future.delayed(const Duration(milliseconds: 120));
      expect(heartbeat.ticksEmitted, greaterThanOrEqualTo(1));

      // Disable heartbeat
      heartbeat.setEnabled(false);
      expect(heartbeat.isEnabled, isFalse);
      final countBefore = heartbeat.ticksEmitted;

      await Future.delayed(const Duration(milliseconds: 100));
      expect(heartbeat.ticksEmitted, equals(countBefore)); // No new ticks when disabled

      // Re-enable and update interval
      heartbeat.setInterval(const Duration(milliseconds: 40));
      heartbeat.setEnabled(true);
      await Future.delayed(const Duration(milliseconds: 90));
      expect(heartbeat.ticksEmitted, greaterThan(countBefore));

      heartbeat.dispose();
    });

    test('SafeModeManager: forceSimulateCrashLoop(3) activates Safe Mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tts = MockTtsService();
      final stateMachine = AppStateMachine(ttsService: tts);
      final safeModeManager = SafeModeManager(prefs: prefs, stateMachine: stateMachine);

      expect(stateMachine.currentState, equals(WayzeState.idle));

      await safeModeManager.forceSimulateCrashLoop(crashCount: 3);
      expect(stateMachine.currentState, equals(WayzeState.safeMode));

      // Reset safe mode restores normal state
      await safeModeManager.resetSafeMode();
      expect(stateMachine.currentState, equals(WayzeState.idle));
    });
  });
}
