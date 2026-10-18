import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayze/data/storage/map_database.dart';
import 'package:wayze/domain/navigation/navigation_graph.dart';

import 'package:path/path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MapDatabase Atomic Writes, Backup & Integrity Validation Tests', () {
    late MapDatabase mapDb;

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'wayze_map.db'));
      final targetFile = File(join(dbPath, 'wayze_map_backup.json'));
      final backupFile = File(join(dbPath, 'wayze_map_backup.json.bak'));
      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
        } catch (_) {}
      }
      if (await targetFile.exists()) await targetFile.delete();
      if (await backupFile.exists()) await backupFile.delete();
      mapDb = MapDatabase();
    });

    tearDown(() async {
      await mapDb.close();
    });

    test('validateGraphIntegrity returns true on default seeded map', () async {
      final isHealthy = await mapDb.validateGraphIntegrity();
      expect(isHealthy, isTrue);
    });

    test('validateGraphIntegrity detects broken edges pointing to missing nodes', () async {
      // Add broken edge referencing non-existent node
      const brokenEdge = NavEdge(
        fromId: 'entrance',
        toId: 'non_existent_room_99',
        distanceMeters: 5.0,
        directionDegrees: 0.0,
      );
      await mapDb.insertEdge(brokenEdge);

      final isHealthy = await mapDb.validateGraphIntegrity();
      expect(isHealthy, isFalse);
    });

    test('saveMapWithBackupAndAtomicWrite preserves backup and writes atomically', () async {
      final initialNodes = await mapDb.getAllNodes();
      expect(initialNodes.isNotEmpty, isTrue);

      // Create new map content with an added room
      final newMapData = {
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'nodes': [
          ...initialNodes.map((n) => n.toMap()),
          {
            'id': 'balcony',
            'name': 'Balcony',
            'x': 5.0,
            'y': 5.0,
            'floor': 1,
            'spoken_description': 'Outdoor balcony',
            'type': 'room',
          }
        ],
        'edges': [],
      };

      final jsonStr = jsonEncode(newMapData);
      await mapDb.saveMapWithBackupAndAtomicWrite(jsonStr);

      final updatedNodes = await mapDb.getAllNodes();
      expect(updatedNodes.any((n) => n.id == 'balcony'), isTrue);

      // Verify restore from backup recovers original state without the balcony
      final restored = await mapDb.restoreFromBackup();
      expect(restored, isTrue);

      final restoredNodes = await mapDb.getAllNodes();
      expect(restoredNodes.any((n) => n.id == 'balcony'), isFalse);
    });
  });
}
