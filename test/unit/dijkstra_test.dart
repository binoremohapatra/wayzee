import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/domain/navigation/navigation_graph.dart';

void main() {
  group('Dijkstra Routing and Step Guidance Tests', () {
    late DijkstraRouter router;

    setUp(() {
      router = DijkstraRouter();
      final nodes = [
        const NavNode(id: 'entrance', name: 'Entrance', x: 0.0, y: 0.0, spokenDescription: 'Entrance door'),
        const NavNode(id: 'hall', name: 'Central Hall', x: 0.0, y: 10.0, spokenDescription: 'Hallway intersection'),
        const NavNode(id: 'library', name: 'Library', x: -10.0, y: 10.0, spokenDescription: 'Library doors'),
        const NavNode(id: 'cafeteria', name: 'Cafeteria', x: 0.0, y: 25.0, spokenDescription: 'Dining area'),
        const NavNode(id: 'stairs', name: 'Stairs', x: 5.0, y: 15.0, spokenDescription: 'Staircase'),
      ];

      final edges = [
        const NavEdge(fromId: 'entrance', toId: 'hall', distanceMeters: 10.0, directionDegrees: 0.0),
        const NavEdge(fromId: 'hall', toId: 'library', distanceMeters: 10.0, directionDegrees: 270.0),
        const NavEdge(fromId: 'hall', toId: 'cafeteria', distanceMeters: 15.0, directionDegrees: 0.0),
        const NavEdge(fromId: 'hall', toId: 'stairs', distanceMeters: 7.0, directionDegrees: 45.0, hazardLevel: 3),
      ];

      router.loadGraph(nodes, edges);
    });

    test('findsPath calculates shortest route between Entrance and Library', () {
      final result = router.findPath(startNodeId: 'entrance', targetNodeId: 'library');

      expect(result, isNotNull);
      expect(result!.pathNodes.map((n) => n.id).toList(), equals(['entrance', 'hall', 'library']));
      expect(result.totalDistanceMeters, equals(20.0));
      expect(result.steps.length, equals(2));
      expect(result.steps[0].spokenInstruction, contains('Head straight for 10 meters'));
      expect(result.steps[1].spokenInstruction, contains('Turn left and walk 10 meters to Library'));
    });

    test('findsPath returns null for unreachable disconnected node', () {
      router.nodes['isolated'] = const NavNode(
        id: 'isolated',
        name: 'Isolated Room',
        x: 100.0,
        y: 100.0,
        spokenDescription: 'Disconnected',
      );

      final result = router.findPath(startNodeId: 'entrance', targetNodeId: 'isolated');
      expect(result, isNull);
    });

    test('findsPath handles start equal to target', () {
      final result = router.findPath(startNodeId: 'entrance', targetNodeId: 'entrance');
      expect(result, isNotNull);
      expect(result!.pathNodes.length, equals(1));
      expect(result.steps, isEmpty);
      expect(result.totalDistanceMeters, equals(0.0));
    });

    test('hazard penalty routes around high-hazard stairs when alternative exists', () {
      // Add safe alternative path to an upper room
      final nodes = [
        const NavNode(id: 'A', name: 'Point A', x: 0, y: 0, spokenDescription: ''),
        const NavNode(id: 'B_stairs', name: 'Stairs B', x: 5, y: 0, spokenDescription: ''),
        const NavNode(id: 'C_ramp', name: 'Ramp C', x: 0, y: 8, spokenDescription: ''),
        const NavNode(id: 'Dest', name: 'Destination', x: 10, y: 8, spokenDescription: ''),
      ];

      final edges = [
        // Path through stairs is shorter in raw meters (10m) but high hazard
        const NavEdge(fromId: 'A', toId: 'B_stairs', distanceMeters: 5.0, directionDegrees: 90.0, hazardLevel: 3),
        const NavEdge(fromId: 'B_stairs', toId: 'Dest', distanceMeters: 5.0, directionDegrees: 0.0, hazardLevel: 3),
        // Path through ramp is longer in raw meters (14m) but zero hazard
        const NavEdge(fromId: 'A', toId: 'C_ramp', distanceMeters: 8.0, directionDegrees: 0.0, hazardLevel: 0),
        const NavEdge(fromId: 'C_ramp', toId: 'Dest', distanceMeters: 6.0, directionDegrees: 90.0, hazardLevel: 0),
      ];

      router.loadGraph(nodes, edges);

      // When avoiding hazards, chooses the ramp
      final safeResult = router.findPath(startNodeId: 'A', targetNodeId: 'Dest', avoidHazards: true);
      expect(safeResult!.pathNodes.map((n) => n.id).toList(), equals(['A', 'C_ramp', 'Dest']));

      // When not avoiding hazards, chooses the raw shorter stair path
      final directResult = router.findPath(startNodeId: 'A', targetNodeId: 'Dest', avoidHazards: false);
      expect(directResult!.pathNodes.map((n) => n.id).toList(), equals(['A', 'B_stairs', 'Dest']));
    });
  });
}
