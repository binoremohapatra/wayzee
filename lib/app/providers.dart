import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/alerts/alert_queue.dart';
import '../domain/models/alert_item.dart';
import '../domain/state/app_state_machine.dart';
import '../domain/vision/vision_tracker.dart';
import '../domain/vision/vision_metrics.dart';
import '../domain/fusion/sensor_source.dart';
import '../domain/fusion/fusion_engine.dart';
import '../domain/navigation/navigation_graph.dart';
import '../data/tts_stt/tts_service.dart';
import '../data/sensors/phone_sensor_source.dart';
import '../data/sensors/mock_cane_source.dart';
import '../data/vision/native_vision_bridge.dart';
import '../data/storage/map_database.dart';
import '../core/accessibility/haptic_service.dart';
import '../core/reliability/thermal_governor.dart';
import '../core/reliability/vision_watchdog.dart';

/// Provider for TTS service
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = FlutterTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for Haptic feedback
final hapticServiceProvider = Provider<HapticService>((ref) {
  return const SystemHapticService();
});

/// Provider for native Android CameraX and Service bridge
final visionBridgeProvider = Provider<VisionBridge>((ref) {
  return NativeVisionBridge();
});

/// Provider for VisionMetrics
final visionMetricsProvider = Provider<VisionMetrics>((ref) {
  return VisionMetrics();
});

/// Provider for AppStateMachine
final stateMachineProvider = Provider<AppStateMachine>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final machine = AppStateMachine(ttsService: tts);
  ref.onDispose(() => machine.dispose());
  return machine;
});

/// Provider for MapDatabase
final mapDatabaseProvider = Provider<MapDatabase>((ref) {
  final db = MapDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for DijkstraRouter
final dijkstraRouterProvider = Provider<DijkstraRouter>((ref) {
  return DijkstraRouter();
});

/// Provider for MockCaneSource
final mockCaneSourceProvider = Provider<MockCaneSource>((ref) {
  final source = MockCaneSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// Provider for PhoneSensorSource
final phoneSensorSourceProvider = Provider<PhoneSensorSource>((ref) {
  final source = PhoneSensorSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// Provider for VisionTracker
final visionTrackerProvider = Provider<VisionTracker>((ref) {
  return VisionTracker();
});

/// Provider for AlertQueue
final alertQueueProvider = Provider<AlertQueue>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptics = ref.watch(hapticServiceProvider);

  return AlertQueue(
    onP0Dispatched: (dangerItem) {
      haptics.danger();
      tts.speak(dangerItem.speechText, priority: AlertPriority.p0Danger);
    },
  );
});

/// Provider for FusionEngine
final fusionEngineProvider = Provider<FusionEngine>((ref) {
  final queue = ref.watch(alertQueueProvider);
  final tracker = ref.watch(visionTrackerProvider);
  final haptics = ref.watch(hapticServiceProvider);

  final engine = FusionEngine(
    alertQueue: queue,
    visionTracker: tracker,
    hapticService: haptics,
  );

  // Attach default phone sensor source
  final phoneSensors = ref.watch(phoneSensorSourceProvider);
  engine.attachSensorSource(phoneSensors);
  phoneSensors.start();

  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Provider for ThermalGovernor
final thermalGovernorProvider = Provider<ThermalGovernor>((ref) {
  final bridge = ref.watch(visionBridgeProvider);
  final tts = ref.watch(ttsServiceProvider);
  final governor = ThermalGovernor(visionBridge: bridge, ttsService: tts);
  ref.onDispose(() => governor.stop());
  return governor;
});

/// Provider for VisionWatchdog
final visionWatchdogProvider = Provider<VisionWatchdog>((ref) {
  final bridge = ref.watch(visionBridgeProvider);
  final tts = ref.watch(ttsServiceProvider);
  final watchdog = VisionWatchdog(visionBridge: bridge, ttsService: tts);
  ref.onDispose(() => watchdog.stop());
  return watchdog;
});
