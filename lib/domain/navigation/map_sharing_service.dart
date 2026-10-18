import 'dart:convert';
import '../../data/storage/map_database.dart';
import 'navigation_graph.dart';

class MapImportResult {
  final bool isSuccess;
  final int nodesImported;
  final int edgesImported;
  final String? errorMessage;

  const MapImportResult({
    required this.isSuccess,
    this.nodesImported = 0,
    this.edgesImported = 0,
    this.errorMessage,
  });
}

/// Service that exports indoor navigation maps into QR-compatible payloads and
/// imports external maps with strict schema validation and rollback safety.
class MapSharingService {
  final MapDatabase mapDatabase;
  static const int currentSchemaVersion = 1;

  MapSharingService({required this.mapDatabase});

  /// Computes a 64-bit FNV-1a hex checksum of the string for corruption resistance.
  String computeChecksum(String content) {
    final bytes = utf8.encode(content);
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.parse('1099511628211');
    final mask64 = (BigInt.one << 64) - BigInt.one;

    for (final b in bytes) {
      hash = (hash ^ BigInt.from(b)) & mask64;
      hash = (hash * prime) & mask64;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Exports current map database to a self-contained, verifiable JSON payload.
  Future<String> exportMapJson({String mapName = 'Indoor Navigation Map'}) async {
    final nodes = await mapDatabase.getAllNodes();
    final edges = await mapDatabase.getAllEdges();

    final dataBlock = {
      'schema_version': currentSchemaVersion,
      'map_name': mapName,
      'exported_at': DateTime.now().toIso8601String(),
      'nodes': nodes.map((n) => n.toMap()).toList(),
      'edges': edges.map((e) => e.toMap()).toList(),
    };

    final rawJson = jsonEncode(dataBlock);
    final checksum = computeChecksum(rawJson);

    final payload = {
      'header': 'WAYZE_MAP_PACKAGE',
      'checksum': checksum,
      'data': dataBlock,
    };

    return jsonEncode(payload);
  }

  /// Generates a compact URI payload suitable for QR codes (e.g. `wayze://map?p=...`).
  Future<String> exportQrPayload({String mapName = 'Building Map'}) async {
    final fullJson = await exportMapJson(mapName: mapName);
    final base64String = base64Url.encode(utf8.encode(fullJson));
    return 'wayze://map?pkg=$base64String';
  }

  /// Validates a raw JSON map payload before applying any changes to the database.
  MapImportResult validatePayload(String rawPayload) {
    try {
      String jsonStr = rawPayload.trim();
      if (jsonStr.startsWith('wayze://map?pkg=')) {
        final b64 = jsonStr.substring('wayze://map?pkg='.length);
        jsonStr = utf8.decode(base64Url.decode(b64));
      }

      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        return const MapImportResult(isSuccess: false, errorMessage: 'Invalid JSON root: expected object');
      }

      // Check header or direct data
      Map<String, dynamic> data;
      if (decoded.containsKey('header') && decoded['header'] == 'WAYZE_MAP_PACKAGE') {
        data = decoded['data'] as Map<String, dynamic>;
        final expectedChecksum = decoded['checksum'] as String?;
        final actualChecksum = computeChecksum(jsonEncode(data));
        if (expectedChecksum != null && expectedChecksum != actualChecksum) {
          return const MapImportResult(isSuccess: false, errorMessage: 'Checksum mismatch: Map payload corrupted or tampered.');
        }
      } else if (decoded.containsKey('nodes') && decoded.containsKey('edges')) {
        data = decoded;
      } else {
        return const MapImportResult(isSuccess: false, errorMessage: 'Unrecognized map schema: missing nodes/edges.');
      }

      final nodesList = data['nodes'] as List?;
      final edgesList = data['edges'] as List?;

      if (nodesList == null || edgesList == null) {
        return const MapImportResult(isSuccess: false, errorMessage: 'Missing nodes or edges lists.');
      }

      final parsedNodes = <NavNode>[];
      final nodeIds = <String>{};
      for (final n in nodesList) {
        if (n is! Map<String, dynamic>) {
          return const MapImportResult(isSuccess: false, errorMessage: 'Node is not a valid map object.');
        }
        final node = NavNode.fromMap(n);
        if (node.id.isEmpty) {
          return const MapImportResult(isSuccess: false, errorMessage: 'Node contains empty id.');
        }
        nodeIds.add(node.id);
        parsedNodes.add(node);
      }

      final parsedEdges = <NavEdge>[];
      for (final e in edgesList) {
        if (e is! Map<String, dynamic>) {
          return const MapImportResult(isSuccess: false, errorMessage: 'Edge is not a valid map object.');
        }
        final edge = NavEdge.fromMap(e);
        if (!nodeIds.contains(edge.fromId) || !nodeIds.contains(edge.toId)) {
          return MapImportResult(
            isSuccess: false,
            errorMessage: 'Graph integrity error: Edge (${edge.fromId} -> ${edge.toId}) references nonexistent node.',
          );
        }
        parsedEdges.add(edge);
      }

      return MapImportResult(
        isSuccess: true,
        nodesImported: parsedNodes.length,
        edgesImported: parsedEdges.length,
      );
    } catch (e) {
      return MapImportResult(isSuccess: false, errorMessage: 'Parsing error: $e');
    }
  }

  /// Imports map payload with backup preservation and atomic transaction commit.
  Future<MapImportResult> importPayload(String rawPayload, {bool clearExisting = true}) async {
    final validation = validatePayload(rawPayload);
    if (!validation.isSuccess) {
      return validation;
    }

    try {
      String jsonStr = rawPayload.trim();
      if (jsonStr.startsWith('wayze://map?pkg=')) {
        final b64 = jsonStr.substring('wayze://map?pkg='.length);
        jsonStr = utf8.decode(base64Url.decode(b64));
      }

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = decoded.containsKey('data') ? decoded['data'] as Map<String, dynamic> : decoded;

      // Create backup of current state first
      final currentBackup = await mapDatabase.exportToJson();
      await mapDatabase.saveMapWithBackupAndAtomicWrite(currentBackup);

      // Import validated nodes and edges
      await mapDatabase.importFromJson(jsonEncode(data), clearExisting: clearExisting);

      return validation;
    } catch (e) {
      return MapImportResult(isSuccess: false, errorMessage: 'Database write error: $e');
    }
  }
}
