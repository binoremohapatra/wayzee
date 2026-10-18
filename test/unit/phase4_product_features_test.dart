import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/data/tts_stt/tts_service.dart';
import 'package:wayze/data/storage/map_database.dart';
import 'package:wayze/domain/models/spatial_zone.dart';
import 'package:wayze/domain/navigation/location_query_service.dart';
import 'package:wayze/domain/navigation/map_sharing_service.dart';
import 'package:wayze/domain/navigation/navigation_graph.dart';
import 'package:wayze/domain/navigation/route_preview_service.dart';
import 'package:wayze/domain/safety/emergency_beacon_service.dart';
import 'package:wayze/domain/vision/offline_sign_ocr.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MapDatabase mapDb;
  late MockTtsService mockTts;
  late MockHapticService mockHaptics;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'wayze_map.db'));
    if (await dbFile.exists()) {
      try {
        await dbFile.delete();
      } catch (_) {}
    }

    mapDb = MapDatabase();
    mockTts = MockTtsService();
    mockHaptics = MockHapticService();

    final db = await mapDb.database;
    await db.delete('edges');
    await db.delete('landmarks');
    await db.delete('nodes');

    // Seed test nodes
    await db.insert('nodes', {
      'id': 'hall',
      'name': 'Central Hall',
      'x': 0.0,
      'y': 0.0,
      'floor': 1,
      'spoken_description': 'Central junction',
      'type': 'corridor',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('nodes', {
      'id': 'restroom',
      'name': 'Accessible Restroom',
      'x': 10.0,
      'y': 0.0,
      'floor': 1,
      'spoken_description': 'Restroom door',
      'type': 'room',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('nodes', {
      'id': 'stairs_node',
      'name': 'East Stairs',
      'x': 0.0,
      'y': 15.0,
      'floor': 1,
      'spoken_description': 'Staircase down',
      'type': 'stairs',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  tearDown(() async {
    await mapDb.close();
  });

  group('Phase 4: "Where am I?" LocationQueryService', () {
    test('Reports current node, floor, and nearest landmark when idle', () async {
      final service = LocationQueryService(mapDatabase: mapDb, ttsService: mockTts);

      final report = await service.queryAndSpeak(
        currentNodeId: 'hall',
        headingDegrees: 0.0, // North
      );

      expect(report.currentNode?.name, equals('Central Hall'));
      expect(report.floor, equals(1));
      expect(report.isNavigating, isFalse);
      expect(report.nearestLandmark?.name, equals('Accessible Restroom'));
      expect(report.distanceToLandmarkMeters, closeTo(10.0, 0.1));
      expect(report.spokenSummary, contains('You are at Central Hall on Floor 1.'));
      expect(report.spokenSummary, contains('Accessible Restroom is 10 meters to your right.'));
      expect(mockTts.spokenPhrases.last, equals(report.spokenSummary));
    });

    test('Reports remaining steps and distance when actively navigating', () async {
      final service = LocationQueryService(mapDatabase: mapDb, ttsService: mockTts);

      final n1 = const NavNode(id: 'hall', name: 'Central Hall', x: 0, y: 0, spokenDescription: '');
      final n2 = const NavNode(id: 'stairs_node', name: 'East Stairs', x: 0, y: 15, spokenDescription: '');
      final step = RouteStep(
        fromNode: n1,
        toNode: n2,
        distanceMeters: 15.0,
        bearingDegrees: 0.0,
        spokenInstruction: 'Head straight for 15 meters to East Stairs.',
      );
      final navResult = NavigationResult(pathNodes: [n1, n2], steps: [step], totalDistanceMeters: 15.0);

      final report = await service.getLocationReport(
        currentNodeId: 'hall',
        activeRoute: navResult,
        currentStepIndex: 0,
      );

      expect(report.isNavigating, isTrue);
      expect(report.destinationName, equals('East Stairs'));
      expect(report.remainingSteps, equals(1));
      expect(report.remainingDistanceMeters, closeTo(15.0, 0.1));
      expect(report.spokenSummary, contains('Navigating to East Stairs. 1 steps remaining, 15 meters to go.'));
    });
  });

  group('Phase 4: Offline Door Sign & Room Number OCR', () {
    test('Identifies room numbers and formats accessible directional utterance', () {
      final ocr = OfflineSignOcrService(debounceCooldown: const Duration(seconds: 10));

      final det = ocr.processText(
        rawOcrText: 'Room 302',
        zone: SpatialZone.right,
        timestampMs: 10000,
      );

      expect(det, isNotNull);
      expect(det!.formattedTitle, equals('Room 302'));
      expect(det.category, equals(SignCategory.roomNumber));
      expect(det.toSpokenUtterance(), equals('Room 302 on your right.'));
    });

    test('Identifies facility keywords (Restroom, Exit, Caution)', () {
      final ocr = OfflineSignOcrService();

      final restroom = ocr.processText(
        rawOcrText: 'WOMEN RESTROOM',
        zone: SpatialZone.left,
        timestampMs: 10000,
      );
      expect(restroom?.formattedTitle, equals('Restroom'));
      expect(restroom?.category, equals(SignCategory.facility));
      expect(restroom?.toSpokenUtterance(), equals('Restroom on your left.'));

      final exit = ocr.processText(
        rawOcrText: 'EMERGENCY EXIT',
        zone: SpatialZone.center,
        timestampMs: 10000,
      );
      expect(exit?.formattedTitle, equals('Emergency Exit'));
      expect(exit?.category, equals(SignCategory.exit));
      expect(exit?.toSpokenUtterance(), equals('Emergency Exit sign straight ahead.'));
    });

    test('Enforces debouncing cooldown to prevent repetitive announcements', () {
      final ocr = OfflineSignOcrService(debounceCooldown: const Duration(seconds: 15));

      final first = ocr.processText(
        rawOcrText: 'Room 401',
        zone: SpatialZone.center,
        timestampMs: 1000,
      );
      expect(first, isNotNull);

      // Same sign during cooldown window should be suppressed
      final second = ocr.processText(
        rawOcrText: 'Room 401',
        zone: SpatialZone.center,
        timestampMs: 5000, // +4s < 15s cooldown
      );
      expect(second, isNull);

      // After cooldown expires, detection is accepted again
      final third = ocr.processText(
        rawOcrText: 'Room 401',
        zone: SpatialZone.center,
        timestampMs: 18000, // +17s > 15s cooldown
      );
      expect(third, isNotNull);
    });
  });

  group('Phase 4: Map Sharing & QR Import/Export', () {
    test('Exports map JSON with FNV-1a checksum and generates QR URI', () async {
      final sharing = MapSharingService(mapDatabase: mapDb);

      final jsonPayload = await sharing.exportMapJson(mapName: 'Test Facility');
      expect(jsonPayload, contains('WAYZE_MAP_PACKAGE'));
      expect(jsonPayload, contains('checksum'));

      final qrUri = await sharing.exportQrPayload(mapName: 'Test Facility');
      expect(qrUri, startsWith('wayze://map?pkg='));

      final validation = sharing.validatePayload(qrUri);
      expect(validation.isSuccess, isTrue);
      expect(validation.nodesImported, equals(3));
    });

    test('Detects corrupted payload and tampered checksum', () {
      final sharing = MapSharingService(mapDatabase: mapDb);

      final tampered = jsonEncode({
        'header': 'WAYZE_MAP_PACKAGE',
        'checksum': 'bad_checksum_123',
        'data': {
          'nodes': [],
          'edges': [],
        },
      });

      final validation = sharing.validatePayload(tampered);
      expect(validation.isSuccess, isFalse);
      expect(validation.errorMessage, contains('Checksum mismatch'));
    });

    test('Rejects graph with invalid edge referencing nonexistent node', () {
      final sharing = MapSharingService(mapDatabase: mapDb);

      final brokenGraph = jsonEncode({
        'nodes': [
          {'id': 'n1', 'name': 'Room 1', 'x': 0, 'y': 0, 'spoken_description': '', 'type': 'room'},
        ],
        'edges': [
          {'from_id': 'n1', 'to_id': 'nonexistent_n2', 'distance_meters': 5.0, 'direction_degrees': 0.0, 'hazard_level': 0},
        ],
      });

      final validation = sharing.validatePayload(brokenGraph);
      expect(validation.isSuccess, isFalse);
      expect(validation.errorMessage, contains('Graph integrity error'));
    });
  });

  group('Phase 4: Route Preview & Step-by-Step Overview', () {
    test('Computes distance, walking time, turns, and highlights stairs hazards', () {
      final preview = RoutePreviewService(ttsService: mockTts, averageWalkingSpeedMps: 0.8);

      final n1 = const NavNode(id: 'entrance', name: 'Entrance', x: 0, y: 0, spokenDescription: '');
      final n2 = const NavNode(id: 'stairs', name: 'Grand Staircase', x: 0, y: 16, spokenDescription: '', type: NodeType.stairs);

      final step = RouteStep(
        fromNode: n1,
        toNode: n2,
        distanceMeters: 16.0,
        bearingDegrees: 0.0,
        spokenInstruction: 'Turn right and walk 16 meters to Grand Staircase.',
      );

      final nav = NavigationResult(pathNodes: [n1, n2], steps: [step], totalDistanceMeters: 16.0);
      final summary = preview.generatePreview(nav);

      expect(summary.totalDistanceMeters, closeTo(16.0, 0.1));
      expect(summary.estimatedWalkingSeconds, equals(20)); // 16 / 0.8 = 20s
      expect(summary.turnCount, equals(1));
      expect(summary.hazards, contains('Stairs at Grand Staircase'));
      expect(summary.spokenOverview, contains('Route from Entrance to Grand Staircase.'));
      expect(summary.spokenOverview, contains('Caution: route includes Stairs at Grand Staircase.'));
    });

    test('Step-by-step interactive preview navigates forward and backward', () async {
      final preview = RoutePreviewService(ttsService: mockTts);

      final n1 = const NavNode(id: 'a', name: 'Node A', x: 0, y: 0, spokenDescription: '');
      final n2 = const NavNode(id: 'b', name: 'Node B', x: 0, y: 10, spokenDescription: '');
      final n3 = const NavNode(id: 'c', name: 'Node C', x: 0, y: 20, spokenDescription: '');

      final steps = [
        RouteStep(fromNode: n1, toNode: n2, distanceMeters: 10, bearingDegrees: 0, spokenInstruction: 'Walk to B.'),
        RouteStep(fromNode: n2, toNode: n3, distanceMeters: 10, bearingDegrees: 0, spokenInstruction: 'Walk to C.'),
      ];
      final nav = NavigationResult(pathNodes: [n1, n2, n3], steps: steps, totalDistanceMeters: 20);
      preview.generatePreview(nav);

      await preview.speakCurrentStep();
      expect(mockTts.spokenPhrases.last, contains('Step 1 of 2: Walk to B.'));

      await preview.nextStep();
      expect(mockTts.spokenPhrases.last, contains('Step 2 of 2: Walk to C.'));

      await preview.previousStep();
      expect(mockTts.spokenPhrases.last, contains('Step 1 of 2: Walk to B.'));
    });
  });

  group('Phase 4: SOS Audio Siren & Emergency Beacon', () {
    test('Starts emergency beacon pulsing danger haptics and high-priority speech', () async {
      final beacon = EmergencyBeaconService(ttsService: mockTts, hapticService: mockHaptics);

      expect(beacon.isBeaconActive, isFalse);

      await beacon.startEmergencyBeacon(emergencyMessage: 'User has fallen in stairwell.');
      expect(beacon.isBeaconActive, isTrue);
      expect(beacon.pulseCount, equals(1));
      expect(mockHaptics.triggerHistory, contains(HapticPattern.danger));
      expect(mockTts.spokenPhrases.last, contains('Emergency! Help needed here! User has fallen in stairwell.'));

      await beacon.stopEmergencyBeacon();
      expect(beacon.isBeaconActive, isFalse);
      expect(mockHaptics.triggerHistory, contains(HapticPattern.confirm));
      expect(mockTts.spokenPhrases.last, equals('Emergency beacon silenced.'));
    });
  });
}
