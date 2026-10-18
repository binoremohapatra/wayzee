import 'spatial_zone.dart';

/// Alert priority levels defining speech scheduling, preemption, and vibration rules.
enum AlertPriority {
  /// P0 Danger: Stairs, drop-offs, obstacles < 50cm.
  /// Flushes lower priorities, interrupts active TTS, and triggers heavy vibration.
  p0Danger(0, 'Danger'),

  /// P1 Navigation: Turn-by-turn route guidance instructions.
  /// Expires after ~2 seconds if stale to avoid giving delayed directions.
  p1Navigation(1, 'Navigation'),

  /// P2 Info: Environmental awareness (doors, distant landmarks).
  /// Spoken only when the speech synthesizer is idle.
  p2Info(2, 'Information');

  final int level;
  final String label;

  const AlertPriority(this.level, this.label);

  bool get isDanger => this == AlertPriority.p0Danger;
  bool get isNavigation => this == AlertPriority.p1Navigation;
  bool get isInfo => this == AlertPriority.p2Info;
}

/// An individual alert queued for speech and haptic delivery.
class AlertItem {
  final String id;
  final String text;
  final AlertPriority priority;
  final String classification;
  final SpatialZone? zone;
  final double? distanceCm;
  final DateTime createdAt;
  final Duration? timeout;

  AlertItem({
    required this.id,
    String? text,
    String? speechText,
    required this.priority,
    String? classification,
    String? label,
    this.zone,
    double? distanceCm,
    double? distanceMeters,
    DateTime? createdAt,
    DateTime? timestamp,
    Duration? timeout,
  })  : text = text ?? speechText ?? '',
        classification = classification ?? label ?? 'obstacle',
        distanceCm = distanceCm ?? (distanceMeters != null ? distanceMeters * 100.0 : null),
        createdAt = createdAt ?? timestamp ?? DateTime.now(),
        timeout = timeout ??
            (priority == AlertPriority.p1Navigation
                ? const Duration(seconds: 2)
                : null);

  String get label => classification;
  String get speechText => text;
  double? get distanceMeters => distanceCm != null ? distanceCm! / 100.0 : null;
  DateTime get timestamp => createdAt;

  /// Key used for (class, zone) cooldown tracking and repeat coalescing.
  String get cooldownKey => '${classification.toLowerCase().trim()}_${zone?.id ?? "none"}';

  /// Returns true if this alert has exceeded its valid time-to-live window.
  bool isExpired(DateTime now) {
    if (timeout == null) return false;
    return now.difference(createdAt) > timeout!;
  }

  AlertItem copyWith({
    String? id,
    String? text,
    AlertPriority? priority,
    String? classification,
    SpatialZone? zone,
    double? distanceCm,
    DateTime? createdAt,
    Duration? timeout,
  }) {
    return AlertItem(
      id: id ?? this.id,
      text: text ?? this.text,
      priority: priority ?? this.priority,
      classification: classification ?? this.classification,
      zone: zone ?? this.zone,
      distanceCm: distanceCm ?? this.distanceCm,
      createdAt: createdAt ?? this.createdAt,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          priority == other.priority;

  @override
  int get hashCode => id.hashCode ^ text.hashCode ^ priority.hashCode;

  @override
  String toString() =>
      'AlertItem(id: $id, priority: ${priority.label}, text: "$text", dist: $distanceCm cm, zone: ${zone?.id})';
}
