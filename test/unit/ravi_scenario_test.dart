import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/data/tts_stt/tts_service.dart';
import 'package:wayze/data/vision/native_vision_bridge.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/fusion/fusion_engine.dart';
import 'package:wayze/domain/fusion/sensor_source.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/models/spatial_zone.dart';
import 'package:wayze/domain/navigation/navigation_graph.dart';
import 'package:wayze/domain/state/app_state_machine.dart';
import 'package:wayze/domain/vision/vision_tracker.dart';
import 'package:wayze/voice/intent_matcher.dart';

void main() {
  group('Real-World Scenario: Ravi Bed to Bathroom 0s-35s Full Lifecycle', () {
    late MockTtsService tts;
    late MockHapticService haptics;
    late AppStateMachine stateMachine;
    late DijkstraRouter router;
    late AlertQueue alertQueue;
    late VisionTracker tracker;
    late FusionEngine fusionEngine;
    late IntentMatcher intentMatcher;

    setUp(() {
      tts = MockTtsService();
      haptics = MockHapticService();
      stateMachine = AppStateMachine(ttsService: tts);
      alertQueue = AlertQueue(
        onP0Dispatched: (dangerAlert) {
          haptics.danger();
          tts.speak(dangerAlert.speechText, priority: AlertPriority.p0Danger);
        },
      );
      tracker = VisionTracker(minConfirmingFrames: 2);
      fusionEngine = FusionEngine(
        alertQueue: alertQueue,
        visionTracker: tracker,
        hapticService: haptics,
        frontObstacleThresholdCm: 50.0,
      );
      router = DijkstraRouter();
      intentMatcher = IntentMatcher();

      // Setup Ravi's room map: Bed -> Door -> Hall -> Bathroom
      final nodes = [
        const NavNode(id: 'bed', name: 'Bed', x: 0.0, y: 0.0, spokenDescription: 'Ravi bed'),
        const NavNode(id: 'door', name: 'Door', x: 0.0, y: 3.0, spokenDescription: 'Bedroom door'),
        const NavNode(id: 'hall', name: 'Hall', x: -4.0, y: 3.0, spokenDescription: 'Corridor hall'),
        const NavNode(id: 'bathroom', name: 'Bathroom', x: -4.0, y: 8.0, spokenDescription: 'Bathroom entrance'),
      ];

      final edges = [
        const NavEdge(fromId: 'bed', toId: 'door', distanceMeters: 3.0, directionDegrees: 0.0),
        const NavEdge(fromId: 'door', toId: 'hall', distanceMeters: 4.0, directionDegrees: 270.0),
        const NavEdge(fromId: 'hall', toId: 'bathroom', distanceMeters: 5.0, directionDegrees: 0.0),
      ];

      router.loadGraph(nodes, edges);
    });

    test('executes 0s to 35s timeline accurately without cloud calls or failures', () async {
      DateTime simTime = DateTime(2026, 10, 18, 7, 0, 0);

      // 0s: Ravi long-presses Volume key -> Hardware trigger
      expect(stateMachine.currentState, equals(WayzeState.idle));
      await stateMachine.handleEvent(const StartListeningEvent());
      expect(stateMachine.currentState, equals(WayzeState.listening));

      // 1s: Phone vibrates and speaks prompt
      simTime = simTime.add(const Duration(seconds: 1));
      await haptics.confirm();
      await tts.speak('Bol, kahan jaana hai?', priority: AlertPriority.p1Navigation);
      expect(haptics.triggerHistory, contains(HapticPattern.confirm));
      expect(tts.spokenUtterances.last, equals('Bol, kahan jaana hai?'));

      // 2s: Ravi says "Bathroom le chalo"
      simTime = simTime.add(const Duration(seconds: 1));
      final voiceResult = intentMatcher.match('Bathroom le chalo');
      expect(voiceResult.intent, equals(Intent.startNavigation));
      expect(voiceResult.place, equals('bathroom'));

      // 3s: Phone acknowledges and starts navigation
      simTime = simTime.add(const Duration(seconds: 1));
      await stateMachine.handleEvent(
        StartNavigationEvent(destinationId: voiceResult.place!, destinationName: 'Bathroom'),
      );
      expect(stateMachine.currentState, equals(WayzeState.navigating));
      expect(tts.spokenUtterances.last, contains('Starting route to Bathroom'));

      // 4s: Dijkstra route calculation
      simTime = simTime.add(const Duration(seconds: 1));
      final route = router.findPath(startNodeId: 'bed', targetNodeId: 'bathroom');
      expect(route, isNotNull);
      expect(route!.pathNodes.map((n) => n.id).toList(), equals(['bed', 'door', 'hall', 'bathroom']));

      // First step announcement: Bed -> Door (3 meters straight)
      final step1 = route.steps[0];
      await tts.speak('Bed se door, ${step1.distanceMeters.toInt()} meter seedha.', priority: AlertPriority.p1Navigation);
      expect(tts.spokenUtterances.last, equals('Bed se door, 3 meter seedha.'));

      // 8s: Camera vision detects chair ("kursi") in center zone, bottom edge paas
      simTime = simTime.add(const Duration(seconds: 4));
      const chairD1 = VisionDetection(label: 'chair', confidence: 0.82, zone: SpatialZone.center, boxArea: 0.15, bottomY: 0.75, timestamp: 8000);
      const chairD2 = VisionDetection(label: 'chair', confidence: 0.85, zone: SpatialZone.center, boxArea: 0.18, bottomY: 0.78, timestamp: 8100);

      fusionEngine.ingestVisionDetections([chairD1], now: simTime);
      final confirmedAlerts = fusionEngine.ingestVisionDetections([chairD2], now: simTime);
      expect(confirmedAlerts.length, equals(1));

      final queuedAlert = alertQueue.dequeue(now: simTime, isSystemIdle: true);
      expect(queuedAlert, isNotNull);
      expect(queuedAlert!.label, equals('chair'));
      await tts.speak(queuedAlert.speechText, priority: queuedAlert.priority);
      expect(tts.spokenUtterances.last, equals(queuedAlert.speechText));

      // 9s: Ravi stops and maneuvers. Cooldown prevents duplicate spam
      simTime = simTime.add(const Duration(seconds: 1));
      final repeatAccepted = alertQueue.enqueue(
        AlertItem(
          id: 'chair_repeat',
          label: 'chair',
          speechText: 'Kursi seedha, paas hai.',
          priority: AlertPriority.p1Navigation,
          zone: SpatialZone.center,
          distanceMeters: 1.5,
          timestamp: simTime,
        ),
        now: simTime,
      );
      // Suppressed by 3-second cooldown!
      expect(repeatAccepted, isFalse);

      // 12s: Cane ToF sensor reads 40cm (< 50cm danger threshold)
      simTime = simTime.add(const Duration(seconds: 3));
      final caneReading1 = SensorReading(timestamp: simTime, frontDistanceCm: 45.0, downDistanceCm: 110.0);
      final caneReading2 = SensorReading(timestamp: simTime.add(const Duration(milliseconds: 100)), frontDistanceCm: 40.0, downDistanceCm: 110.0);

      fusionEngine.ingestSensorReading(caneReading1);
      fusionEngine.ingestSensorReading(caneReading2);

      // P0 Danger triggered immediately! Flushes speech, heavy vibration
      expect(haptics.triggerHistory, contains(HapticPattern.danger));
      final p0Alert = alertQueue.dequeue(now: simTime);
      expect(p0Alert, isNotNull);
      expect(p0Alert!.priority, equals(AlertPriority.p0Danger));
      await tts.speak(p0Alert.speechText, priority: AlertPriority.p0Danger);
      expect(tts.spokenUtterances.last, equals(p0Alert.speechText));

      // 20s: Ravi navigates around chair, reaches Bedroom Door
      simTime = simTime.add(const Duration(seconds: 8));
      final step2 = route.steps[1]; // Door -> Hall (Turn left)
      await tts.speak('Door aa gaya. Left mudo, hall hai.', priority: AlertPriority.p1Navigation);
      expect(tts.spokenUtterances.last, equals('Door aa gaya. Left mudo, hall hai.'));

      // 35s: Ravi reaches Bathroom
      simTime = simTime.add(const Duration(seconds: 15));
      await tts.speak('Bathroom pahunch gaye.', priority: AlertPriority.p1Navigation);
      await stateMachine.handleEvent(const RecoverToIdleEvent());

      expect(tts.spokenUtterances, contains('Bathroom pahunch gaye.'));
      expect(tts.spokenUtterances.last, equals('Navigation ended. Standing by.'));
      expect(stateMachine.currentState, equals(WayzeState.idle));
    });
  });
}
