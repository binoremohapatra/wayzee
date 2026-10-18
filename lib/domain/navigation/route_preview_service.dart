import 'dart:math' as math;
import 'navigation_graph.dart';
import '../../data/tts_stt/tts_service.dart';

/// Summary metadata for an indoor route preview.
class RoutePreviewSummary {
  final String startName;
  final String destinationName;
  final double totalDistanceMeters;
  final int estimatedWalkingSeconds;
  final int turnCount;
  final List<String> hazards;
  final List<String> stepInstructions;
  final String spokenOverview;

  const RoutePreviewSummary({
    required this.startName,
    required this.destinationName,
    required this.totalDistanceMeters,
    required this.estimatedWalkingSeconds,
    required this.turnCount,
    required this.hazards,
    required this.stepInstructions,
    required this.spokenOverview,
  });
}

/// Service allowing visually impaired users to hear a full route breakdown
/// and navigate step-by-step previews before moving.
class RoutePreviewService {
  final TtsService ttsService;
  final double averageWalkingSpeedMps; // default: 0.8 m/s for blind indoor navigation

  NavigationResult? _currentResult;
  RoutePreviewSummary? _currentSummary;
  int _activeStepIndex = 0;

  RoutePreviewService({
    required this.ttsService,
    this.averageWalkingSpeedMps = 0.8,
  });

  RoutePreviewSummary? get currentSummary => _currentSummary;
  NavigationResult? get currentResult => _currentResult;
  int get activeStepIndex => _activeStepIndex;

  /// Analyzes a navigation result and creates a comprehensive preview summary.
  RoutePreviewSummary generatePreview(NavigationResult result) {
    _currentResult = result;
    _activeStepIndex = 0;

    final start = result.pathNodes.isNotEmpty ? result.pathNodes.first.name : 'Start';
    final dest = result.pathNodes.isNotEmpty ? result.pathNodes.last.name : 'Destination';
    final totalDist = result.totalDistanceMeters;
    final walkingSec = (totalDist / averageWalkingSpeedMps).round();

    int turns = 0;
    final hazards = <String>[];
    final steps = <String>[];

    for (var i = 0; i < result.steps.length; i++) {
      final step = result.steps[i];
      steps.add(step.spokenInstruction);

      // Check turn
      final lower = step.spokenInstruction.toLowerCase();
      if (lower.contains('turn right') || lower.contains('turn left')) {
        turns++;
      }

      // Check hazard nodes
      if (step.toNode.type == NodeType.stairs) {
        hazards.add('Stairs at ${step.toNode.name}');
      }
    }

    final overview = _buildSpokenOverview(
      startName: start,
      destinationName: dest,
      distMeters: totalDist,
      seconds: walkingSec,
      turnCount: turns,
      hazards: hazards,
      steps: steps,
    );

    final summary = RoutePreviewSummary(
      startName: start,
      destinationName: dest,
      totalDistanceMeters: totalDist,
      estimatedWalkingSeconds: walkingSec,
      turnCount: turns,
      hazards: hazards,
      stepInstructions: steps,
      spokenOverview: overview,
    );

    _currentSummary = summary;
    return summary;
  }

  /// Speaks the complete route overview out loud
  Future<void> speakOverview([NavigationResult? result]) async {
    final summary = result != null ? generatePreview(result) : _currentSummary;
    if (summary != null) {
      await ttsService.speak(summary.spokenOverview);
    }
  }

  /// Speaks the current step in the step-by-step preview
  Future<void> speakCurrentStep() async {
    final summary = _currentSummary;
    if (summary == null || summary.stepInstructions.isEmpty) return;

    final stepNum = _activeStepIndex + 1;
    final total = summary.stepInstructions.length;
    final instruction = summary.stepInstructions[_activeStepIndex];

    await ttsService.speak('Step $stepNum of $total: $instruction');
  }

  /// Advances to next preview step and speaks it
  Future<void> nextStep() async {
    final summary = _currentSummary;
    if (summary == null || summary.stepInstructions.isEmpty) return;

    if (_activeStepIndex < summary.stepInstructions.length - 1) {
      _activeStepIndex++;
      await speakCurrentStep();
    } else {
      await ttsService.speak('You have reached the end of the route preview.');
    }
  }

  /// Moves to previous preview step and speaks it
  Future<void> previousStep() async {
    final summary = _currentSummary;
    if (summary == null || summary.stepInstructions.isEmpty) return;

    if (_activeStepIndex > 0) {
      _activeStepIndex--;
      await speakCurrentStep();
    } else {
      await ttsService.speak('Already at the first step.');
    }
  }

  String _buildSpokenOverview({
    required String startName,
    required String destinationName,
    required double distMeters,
    required int seconds,
    required int turnCount,
    required List<String> hazards,
    required List<String> steps,
  }) {
    final buf = StringBuffer();
    final distInt = math.max(1, distMeters.round());

    buf.write('Route from $startName to $destinationName. ');
    buf.write('Total distance $distInt meters, approximately $seconds seconds walk. ');

    if (turnCount > 0) {
      buf.write('$turnCount turn${turnCount > 1 ? "s" : ""}. ');
    } else {
      buf.write('Straight route with no turns. ');
    }

    if (hazards.isNotEmpty) {
      buf.write('Caution: route includes ${hazards.join(", ")}. ');
    } else {
      buf.write('Route is clear of stairs and hazards. ');
    }

    if (steps.isNotEmpty) {
      buf.write('First step: ${steps.first}');
    }

    return buf.toString().trim();
  }
}
