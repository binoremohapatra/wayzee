import 'dart:math';

enum NodeType {
  room,
  corridor,
  landmark,
  door,
  stairs,
  elevator,
}

class NavNode {
  final String id;
  final String name;
  final double x;
  final double y;
  final int floor;
  final String spokenDescription;
  final NodeType type;

  const NavNode({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.floor = 1,
    required this.spokenDescription,
    this.type = NodeType.corridor,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'floor': floor,
        'spoken_description': spokenDescription,
        'type': type.name,
      };

  factory NavNode.fromMap(Map<String, dynamic> map) => NavNode(
        id: map['id'] as String,
        name: map['name'] as String,
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        floor: (map['floor'] as num?)?.toInt() ?? 1,
        spokenDescription: map['spoken_description'] as String? ?? '',
        type: NodeType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => NodeType.corridor,
        ),
      );
}

class NavEdge {
  final String fromId;
  final String toId;
  final double distanceMeters;
  final double directionDegrees; // 0..360 where 0 is North/Straight
  final int hazardLevel; // 0 = clear, 1 = threshold/doorsill, 2 = stairs/narrow

  const NavEdge({
    required this.fromId,
    required this.toId,
    required this.distanceMeters,
    required this.directionDegrees,
    this.hazardLevel = 0,
  });

  Map<String, dynamic> toMap() => {
        'from_id': fromId,
        'to_id': toId,
        'distance_meters': distanceMeters,
        'direction_degrees': directionDegrees,
        'hazard_level': hazardLevel,
      };

  factory NavEdge.fromMap(Map<String, dynamic> map) => NavEdge(
        fromId: map['from_id'] as String,
        toId: map['to_id'] as String,
        distanceMeters: (map['distance_meters'] as num).toDouble(),
        directionDegrees: (map['direction_degrees'] as num).toDouble(),
        hazardLevel: (map['hazard_level'] as num?)?.toInt() ?? 0,
      );
}

class RouteStep {
  final NavNode fromNode;
  final NavNode toNode;
  final double distanceMeters;
  final double bearingDegrees;
  final String spokenInstruction;

  const RouteStep({
    required this.fromNode,
    required this.toNode,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.spokenInstruction,
  });
}

class NavigationResult {
  final List<NavNode> pathNodes;
  final List<RouteStep> steps;
  final double totalDistanceMeters;

  const NavigationResult({
    required this.pathNodes,
    required this.steps,
    required this.totalDistanceMeters,
  });
}

/// Dijkstra graph router with hazard penalty weighting and spoken instruction generation.
class DijkstraRouter {
  final Map<String, NavNode> nodes = {};
  final List<NavEdge> edges = [];

  void loadGraph(List<NavNode> newNodes, List<NavEdge> newEdges) {
    nodes.clear();
    edges.clear();
    for (final node in newNodes) {
      nodes[node.id] = node;
    }
    edges.addAll(newEdges);
  }

  /// Calculates shortest path between [startNodeId] and [targetNodeId].
  /// Returns null if no reachable path exists.
  NavigationResult? findPath({
    required String startNodeId,
    required String targetNodeId,
    bool avoidHazards = true,
  }) {
    if (!nodes.containsKey(startNodeId) || !nodes.containsKey(targetNodeId)) {
      return null;
    }

    if (startNodeId == targetNodeId) {
      final start = nodes[startNodeId]!;
      return NavigationResult(pathNodes: [start], steps: [], totalDistanceMeters: 0.0);
    }

    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{};

    for (final nodeId in nodes.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
      unvisited.add(nodeId);
    }
    distances[startNodeId] = 0.0;

    // Adjacency list: from -> list of edges
    final adjacency = <String, List<NavEdge>>{};
    for (final edge in edges) {
      adjacency.putIfAbsent(edge.fromId, () => []).add(edge);
      // Bidirectional graph
      adjacency.putIfAbsent(edge.toId, () => []).add(
            NavEdge(
              fromId: edge.toId,
              toId: edge.fromId,
              distanceMeters: edge.distanceMeters,
              directionDegrees: (edge.directionDegrees + 180.0) % 360.0,
              hazardLevel: edge.hazardLevel,
            ),
          );
    }

    while (unvisited.isNotEmpty) {
      // Find unvisited node with lowest distance
      String? current;
      double lowestDistance = double.infinity;
      for (final nodeId in unvisited) {
        final dist = distances[nodeId]!;
        if (dist < lowestDistance) {
          lowestDistance = dist;
          current = nodeId;
        }
      }

      if (current == null || lowestDistance == double.infinity) {
        break; // Remaining nodes are unreachable
      }

      if (current == targetNodeId) {
        break; // Reached target
      }

      unvisited.remove(current);

      final neighbors = adjacency[current] ?? [];
      for (final edge in neighbors) {
        if (!unvisited.contains(edge.toId)) continue;

        // Hazard penalty weight (e.g. +3 meters per hazard level if avoiding hazards)
        final penalty = avoidHazards ? edge.hazardLevel * 3.0 : 0.0;
        final tentativeDist = distances[current]! + edge.distanceMeters + penalty;

        if (tentativeDist < distances[edge.toId]!) {
          distances[edge.toId] = tentativeDist;
          previous[edge.toId] = current;
        }
      }
    }

    // Reconstruct path
    final path = <String>[];
    String? curr = targetNodeId;
    while (curr != null) {
      path.insert(0, curr);
      curr = previous[curr];
    }

    if (path.isEmpty || path.first != startNodeId) {
      return null; // No path found
    }

    final pathNodes = path.map((id) => nodes[id]!).toList();
    final steps = <RouteStep>[];
    double totalDist = 0.0;
    double? previousBearing;

    for (int i = 0; i < pathNodes.length - 1; i++) {
      final u = pathNodes[i];
      final v = pathNodes[i + 1];

      // Find matching edge
      final edge = (adjacency[u.id] ?? []).firstWhere(
        (e) => e.toId == v.id,
        orElse: () => NavEdge(
          fromId: u.id,
          toId: v.id,
          distanceMeters: sqrt(pow(v.x - u.x, 2) + pow(v.y - u.y, 2)),
          directionDegrees: (atan2(v.y - u.y, v.x - u.x) * 180 / pi) % 360,
        ),
      );

      totalDist += edge.distanceMeters;
      final instruction = _buildTurnInstruction(
        previousBearing: previousBearing,
        currentBearing: edge.directionDegrees,
        distanceMeters: edge.distanceMeters,
        targetNodeName: v.name,
      );
      previousBearing = edge.directionDegrees;

      steps.add(
        RouteStep(
          fromNode: u,
          toNode: v,
          distanceMeters: edge.distanceMeters,
          bearingDegrees: edge.directionDegrees,
          spokenInstruction: instruction,
        ),
      );
    }

    return NavigationResult(
      pathNodes: pathNodes,
      steps: steps,
      totalDistanceMeters: totalDist,
    );
  }

  String _buildTurnInstruction({
    double? previousBearing,
    required double currentBearing,
    required double distanceMeters,
    required String targetNodeName,
  }) {
    final distInt = max(1, distanceMeters.round());
    if (previousBearing == null) {
      return 'Head straight for $distInt meters toward $targetNodeName.';
    }

    double diff = (currentBearing - previousBearing) % 360;
    if (diff > 180) diff -= 360;

    String turnDirection;
    if (diff.abs() < 20) {
      turnDirection = 'Continue straight';
    } else if (diff > 20 && diff <= 60) {
      turnDirection = 'Turn slight right';
    } else if (diff > 60 && diff <= 120) {
      turnDirection = 'Turn right';
    } else if (diff > 120) {
      turnDirection = 'Turn sharp right';
    } else if (diff < -20 && diff >= -60) {
      turnDirection = 'Turn slight left';
    } else if (diff < -60 && diff >= -120) {
      turnDirection = 'Turn left';
    } else {
      turnDirection = 'Turn sharp left';
    }

    return '$turnDirection and walk $distInt meters to $targetNodeName.';
  }
}
