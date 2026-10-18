import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/navigation/navigation_graph.dart';

class MapDatabase {
  static const String databaseName = 'wayze_map.db';
  static const int currentVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE nodes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        floor INTEGER NOT NULL DEFAULT 1,
        spoken_description TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'corridor'
      )
    ''');

    await db.execute('''
      CREATE TABLE edges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        distance_meters REAL NOT NULL,
        direction_degrees REAL NOT NULL,
        hazard_level INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(from_id) REFERENCES nodes(id) ON DELETE CASCADE,
        FOREIGN KEY(to_id) REFERENCES nodes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE landmarks (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        name TEXT NOT NULL,
        audio_prompt TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(node_id) REFERENCES nodes(id) ON DELETE CASCADE
      )
    ''');

    // Seed default accessible building map for immediate out-of-the-box testing
    await _seedDefaultBuilding(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 2 migration
      await db.execute('ALTER TABLE nodes ADD COLUMN spoken_description TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE edges ADD COLUMN hazard_level INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS landmarks (
          id TEXT PRIMARY KEY,
          node_id TEXT NOT NULL,
          name TEXT NOT NULL,
          audio_prompt TEXT,
          created_at INTEGER NOT NULL,
          FOREIGN KEY(node_id) REFERENCES nodes(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _seedDefaultBuilding(Database db) async {
    final nodes = [
      NavNode(id: 'entrance', name: 'Main Entrance', x: 0.0, y: 0.0, spokenDescription: 'Main double doors', type: NodeType.door),
      NavNode(id: 'corridor_center', name: 'Central Hall', x: 0.0, y: 10.0, spokenDescription: 'Central junction hallway', type: NodeType.corridor),
      NavNode(id: 'library', name: 'Library', x: -12.0, y: 10.0, spokenDescription: 'Library reading room entrance', type: NodeType.room),
      NavNode(id: 'washroom', name: 'Washroom', x: 12.0, y: 10.0, spokenDescription: 'Accessible restrooms', type: NodeType.room),
      NavNode(id: 'cafeteria', name: 'Cafeteria', x: 0.0, y: 25.0, spokenDescription: 'Food court and dining tables', type: NodeType.room),
      NavNode(id: 'stairs', name: 'Staircase East', x: 8.0, y: 18.0, spokenDescription: 'Flight of stairs down to basement', type: NodeType.stairs),
    ];

    final edges = [
      const NavEdge(fromId: 'entrance', toId: 'corridor_center', distanceMeters: 10.0, directionDegrees: 0.0),
      const NavEdge(fromId: 'corridor_center', toId: 'library', distanceMeters: 12.0, directionDegrees: 270.0),
      const NavEdge(fromId: 'corridor_center', toId: 'washroom', distanceMeters: 12.0, directionDegrees: 90.0),
      const NavEdge(fromId: 'corridor_center', toId: 'cafeteria', distanceMeters: 15.0, directionDegrees: 0.0),
      const NavEdge(fromId: 'corridor_center', toId: 'stairs', distanceMeters: 10.0, directionDegrees: 45.0, hazardLevel: 2),
    ];

    for (final node in nodes) {
      await db.insert('nodes', node.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final edge in edges) {
      await db.insert('edges', edge.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<NavNode>> getAllNodes() async {
    final db = await database;
    final records = await db.query('nodes');
    return records.map((e) => NavNode.fromMap(e)).toList();
  }

  Future<List<NavEdge>> getAllEdges() async {
    final db = await database;
    final records = await db.query('edges');
    return records.map((e) => NavEdge.fromMap(e)).toList();
  }

  Future<void> insertNode(NavNode node) async {
    final db = await database;
    await db.insert('nodes', node.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEdge(NavEdge edge) async {
    final db = await database;
    await db.insert('edges', edge.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Voice-driven setup flow: Marks a new landmark at current estimated location
  /// and automatically connects it to the [previousNodeId].
  Future<NavNode> markLandmarkHere({
    required String landmarkName,
    required String previousNodeId,
    required double distanceMeters,
    required double relativeBearingDegrees,
    String? audioPrompt,
  }) async {
    final db = await database;
    final prevRecords = await db.query('nodes', where: 'id = ?', whereArgs: [previousNodeId]);
    if (prevRecords.isEmpty) {
      throw ArgumentError('Previous node $previousNodeId does not exist.');
    }

    final prevNode = NavNode.fromMap(prevRecords.first);

    // Compute coordinates relative to previous node
    final rad = relativeBearingDegrees * 3.141592653589793 / 180.0;
    final newX = prevNode.x + distanceMeters * 3.141592653589793 * 0.3 * (relativeBearingDegrees > 180 ? -1 : 1);
    final newY = prevNode.y + distanceMeters;

    final sanitizedId = landmarkName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final newNode = NavNode(
      id: '${sanitizedId}_${DateTime.now().millisecondsSinceEpoch}',
      name: landmarkName,
      x: newX,
      y: newY,
      floor: prevNode.floor,
      spokenDescription: 'Custom landmark $landmarkName',
      type: NodeType.landmark,
    );

    final edge = NavEdge(
      fromId: previousNodeId,
      toId: newNode.id,
      distanceMeters: distanceMeters,
      directionDegrees: relativeBearingDegrees,
    );

    await insertNode(newNode);
    await insertEdge(edge);

    await db.insert('landmarks', {
      'id': 'lm_${DateTime.now().millisecondsSinceEpoch}',
      'node_id': newNode.id,
      'name': landmarkName,
      'audio_prompt': audioPrompt ?? 'Approaching $landmarkName',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return newNode;
  }

  /// Exports map schema and data to JSON for offline backup / export
  Future<String> exportToJson() async {
    final nodes = await getAllNodes();
    final edges = await getAllEdges();

    final exportMap = {
      'version': currentVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'nodes': nodes.map((n) => n.toMap()).toList(),
      'edges': edges.map((e) => e.toMap()).toList(),
    };

    return jsonEncode(exportMap);
  }

  /// Imports and overwrites or merges map data from JSON
  Future<void> importFromJson(String jsonContent, {bool clearExisting = true}) async {
    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final nodesList = (decoded['nodes'] as List).cast<Map<String, dynamic>>();
    final edgesList = (decoded['edges'] as List).cast<Map<String, dynamic>>();

    final db = await database;
    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete('landmarks');
        await txn.delete('edges');
        await txn.delete('nodes');
      }

      for (final n in nodesList) {
        await txn.insert('nodes', n, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final e in edgesList) {
        await txn.insert('edges', e, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Validates graph consistency (no broken edges, no orphaned references)
  Future<bool> validateGraphIntegrity() async {
    final nodes = await getAllNodes();
    final edges = await getAllEdges();

    final nodeIds = nodes.map((n) => n.id).toSet();
    for (final edge in edges) {
      if (!nodeIds.contains(edge.fromId) || !nodeIds.contains(edge.toId)) {
        return false; // Broken edge pointing to missing node
      }
    }
    return true;
  }

  /// Atomic file write with .bak backup preservation before any overwrite
  Future<void> saveMapWithBackupAndAtomicWrite(String jsonContent) async {
    final dbPath = await getDatabasesPath();
    final targetFile = File(join(dbPath, 'wayze_map_backup.json'));
    final backupFile = File(join(dbPath, 'wayze_map_backup.json.bak'));
    final tempFile = File(join(dbPath, 'wayze_map_backup.json.tmp'));

    // 1. Create .bak backup before modifying
    if (await targetFile.exists()) {
      await targetFile.copy(backupFile.path);
    } else {
      final currentBackupJson = await exportToJson();
      await backupFile.writeAsString(currentBackupJson, flush: true);
    }

    // 2. Atomic write to .tmp first
    await tempFile.writeAsString(jsonContent, flush: true);

    // 3. Rename .tmp to destination file
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);

    // 4. Update SQLite transaction
    await importFromJson(jsonContent);
  }

  /// Restores from .bak if target corrupted or validation fails
  Future<bool> restoreFromBackup() async {
    final dbPath = await getDatabasesPath();
    final backupFile = File(join(dbPath, 'wayze_map_backup.json.bak'));
    if (!await backupFile.exists()) return false;

    final content = await backupFile.readAsString();
    await importFromJson(content);
    return true;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
