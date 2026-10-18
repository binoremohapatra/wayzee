import 'dart:math' as math;
import '../navigation/navigation_graph.dart';
import '../../data/storage/map_database.dart';
import '../../data/tts_stt/tts_service.dart';

/// Structured result of a "Where am I?" situational awareness query.
class LocationReport {
  final NavNode? currentNode;
  final int floor;
  final NavNode? nearestLandmark;
  final double? distanceToLandmarkMeters;
  final String? landmarkRelativeDirection;
  final bool isNavigating;
  final String? destinationName;
  final int remainingSteps;
  final double remainingDistanceMeters;
  final String spokenSummary;

  const LocationReport({
    this.currentNode,
    required this.floor,
    this.nearestLandmark,
    this.distanceToLandmarkMeters,
    this.landmarkRelativeDirection,
    required this.isNavigating,
    this.destinationName,
    this.remainingSteps = 0,
    this.remainingDistanceMeters = 0.0,
    required this.spokenSummary,
  });
}

/// Service that computes and speaks real-time location reports for blind users.
class LocationQueryService {
  final MapDatabase mapDatabase;
  final TtsService ttsService;

  LocationQueryService({
    required this.mapDatabase,
    required this.ttsService,
  });

  /// Computes a location report given current location, route progress, and optional compass heading.
  Future<LocationReport> getLocationReport({
    String? currentNodeId,
    NavigationResult? activeRoute,
    int currentStepIndex = 0,
    double? headingDegrees,
  }) async {
    final allNodes = await mapDatabase.getAllNodes();
    NavNode? current;

    if (currentNodeId != null && currentNodeId.isNotEmpty) {
      current = allNodes.firstWhere(
        (n) => n.id == currentNodeId,
        orElse: () => allNodes.isNotEmpty ? allNodes.first : const NavNode(
          id: 'unknown',
          name: 'Current Location',
          x: 0,
          y: 0,
          spokenDescription: 'Indoor area',
        ),
      );
    } else if (allNodes.isNotEmpty) {
      current = allNodes.first;
    }

    final floor = current?.floor ?? 1;

    // Find nearest landmark
    NavNode? nearestLm;
    double? minLmDistance;
    String? relativeDirection;

    if (current != null) {
      final landmarks = allNodes.where((n) => n.id != current!.id && (n.type == NodeType.landmark || n.type == NodeType.room || n.type == NodeType.door));
      for (final lm in landmarks) {
        final dist = math.sqrt(math.pow(lm.x - current.x, 2) + math.pow(lm.y - current.y, 2));
        if (minLmDistance == null || dist < minLmDistance) {
          minLmDistance = dist;
          nearestLm = lm;
        }
      }

      if (nearestLm != null && minLmDistance != null) {
        final angleDeg = (math.atan2(nearestLm.x - current.x, nearestLm.y - current.y) * 180 / math.pi) % 360;
        final refHeading = headingDegrees ?? 0.0;
        double diff = (angleDeg - refHeading) % 360;
        if (diff > 180) diff -= 360;

        if (diff.abs() <= 30) {
          relativeDirection = 'straight ahead';
        } else if (diff > 30 && diff <= 120) {
          relativeDirection = 'to your right';
        } else if (diff < -30 && diff >= -120) {
          relativeDirection = 'to your left';
        } else {
          relativeDirection = 'behind you';
        }
      }
    }

    // Navigation progress details
    final isNavigating = activeRoute != null && activeRoute.steps.isNotEmpty;
    String? destination;
    int remainingSteps = 0;
    double remainingDistance = 0.0;

    if (isNavigating) {
      destination = activeRoute.pathNodes.last.name;
      final totalSteps = activeRoute.steps.length;
      remainingSteps = math.max(0, totalSteps - currentStepIndex);
      for (int i = currentStepIndex; i < totalSteps; i++) {
        remainingDistance += activeRoute.steps[i].distanceMeters;
      }
    }

    // Construct accessible spoken summary
    final spokenSummary = _buildSpokenSummary(
      currentNode: current,
      floor: floor,
      nearestLandmark: nearestLm,
      distMeters: minLmDistance,
      relativeDirection: relativeDirection,
      isNavigating: isNavigating,
      destination: destination,
      remainingSteps: remainingSteps,
      remainingDistance: remainingDistance,
    );

    return LocationReport(
      currentNode: current,
      floor: floor,
      nearestLandmark: nearestLm,
      distanceToLandmarkMeters: minLmDistance,
      landmarkRelativeDirection: relativeDirection,
      isNavigating: isNavigating,
      destinationName: destination,
      remainingSteps: remainingSteps,
      remainingDistanceMeters: remainingDistance,
      spokenSummary: spokenSummary,
    );
  }

  /// Speaks the computed location report out loud through TTS
  Future<LocationReport> queryAndSpeak({
    String? currentNodeId,
    NavigationResult? activeRoute,
    int currentStepIndex = 0,
    double? headingDegrees,
  }) async {
    final report = await getLocationReport(
      currentNodeId: currentNodeId,
      activeRoute: activeRoute,
      currentStepIndex: currentStepIndex,
      headingDegrees: headingDegrees,
    );

    await ttsService.speak(report.spokenSummary);
    return report;
  }

  String _buildSpokenSummary({
    NavNode? currentNode,
    required int floor,
    NavNode? nearestLandmark,
    double? distMeters,
    String? relativeDirection,
    required bool isNavigating,
    String? destination,
    required int remainingSteps,
    required double remainingDistance,
  }) {
    final buf = StringBuffer();

    if (currentNode != null) {
      buf.write('You are at ${currentNode.name} on Floor $floor. ');
    } else {
      buf.write('You are on Floor $floor. ');
    }

    if (isNavigating && destination != null) {
      final distInt = math.max(1, remainingDistance.round());
      buf.write('Navigating to $destination. $remainingSteps steps remaining, $distInt meters to go. ');
    }

    if (nearestLandmark != null && distMeters != null && relativeDirection != null) {
      final lmDistInt = math.max(1, distMeters.round());
      buf.write('${nearestLandmark.name} is $lmDistInt meters $relativeDirection.');
    }

    return buf.toString().trim();
  }
}
