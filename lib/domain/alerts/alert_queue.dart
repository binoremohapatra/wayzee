import 'dart:collection';
import '../models/alert_item.dart';

/// Cooldown and distance history record for (class, zone) pairs.
class _AlertHistoryRecord {
  final DateTime timestamp;
  final double? distanceCm;

  _AlertHistoryRecord({
    required this.timestamp,
    this.distanceCm,
  });
}

/// Priority-based alert queue with deduplication, cooldowns, and stale item expiration.
class AlertQueue {
  final Duration cooldownDuration;
  final Duration p1StaleDuration;
  final int maxQueueSize;

  // Internal queue
  final List<AlertItem> _queue = [];

  // Cooldown tracking per cooldownKey (class_zone)
  final Map<String, _AlertHistoryRecord> _history = {};

  // Callbacks for hardware & audio integration
  final void Function(AlertItem dangerItem)? onP0DangerTriggered;

  AlertQueue({
    this.cooldownDuration = const Duration(seconds: 3),
    this.p1StaleDuration = const Duration(seconds: 2),
    this.maxQueueSize = 10,
    void Function(AlertItem dangerItem)? onP0DangerTriggered,
    void Function(AlertItem dangerItem)? onP0Dispatched,
  }) : onP0DangerTriggered = onP0DangerTriggered ?? onP0Dispatched;

  AlertItem? dequeue({DateTime? now, bool isSystemIdle = true}) =>
      pollNext(isTtsIdle: isSystemIdle, now: now);

  /// Enqueues an [item] according to priority, cooldown, and repeat coalescing rules.
  /// Returns `true` if the item was accepted into the queue, `false` if dropped (e.g. cooldown or duplicate).
  bool enqueue(AlertItem item, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    // 1. P0 Danger bypasses all cooldowns and flushes lower priorities
    if (item.priority == AlertPriority.p0Danger) {
      _handleP0Danger(item, currentTime);
      return true;
    }

    // 2. Cooldown check: 3s per (class, zone)
    final key = item.cooldownKey;
    final lastRecord = _history[key];
    if (lastRecord != null) {
      final elapsed = currentTime.difference(lastRecord.timestamp);
      if (elapsed < cooldownDuration) {
        // Distance override check:
        // If the obstacle gets significantly closer (>= 20% or >= 30cm closer),
        // override the 3s cooldown immediately.
        final distanceOverridden = _checkDistanceOverride(
          lastDistance: lastRecord.distanceCm,
          newDistance: item.distanceCm,
        );

        if (!distanceOverridden) {
          // Suppressed by active cooldown
          return false;
        }
      }
    }

    // 3. Repeat Coalescing:
    // If an identical alert is already queued and waiting to be spoken, coalesce it.
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].cooldownKey == key && _queue[i].text == item.text) {
        // Update existing item with the latest timestamp and closer distance
        _queue[i] = _queue[i].copyWith(
          createdAt: currentTime,
          distanceCm: item.distanceCm ?? _queue[i].distanceCm,
        );
        _recordHistory(key, currentTime, item.distanceCm);
        return true;
      }
    }

    // 4. Stale item cleanup
    _purgeExpired(currentTime);

    // 5. Queue capacity bounding
    if (_queue.length >= maxQueueSize) {
      // Remove lowest priority item (P2 first, then oldest P1)
      final p2Index = _queue.lastIndexWhere((e) => e.priority == AlertPriority.p2Info);
      if (p2Index != -1) {
        _queue.removeAt(p2Index);
      } else {
        _queue.removeLast();
      }
    }

    // 6. Insert sorted by priority level (P0: 0, P1: 1, P2: 2)
    _insertSorted(item);

    // 7. Record cooldown history
    _recordHistory(key, currentTime, item.distanceCm);
    return true;
  }

  /// Polls the next alert to speak.
  /// - P0 Danger items are returned immediately.
  /// - P1 Navigation items are returned if not stale.
  /// - P2 Info items are returned ONLY if [isTtsIdle] is true.
  AlertItem? pollNext({required bool isTtsIdle, DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    _purgeExpired(currentTime);

    if (_queue.isEmpty) return null;

    final top = _queue.first;

    // P0 always preempts
    if (top.priority == AlertPriority.p0Danger) {
      return _queue.removeAt(0);
    }

    // P1 Navigation spoken when idle or ready
    if (top.priority == AlertPriority.p1Navigation) {
      if (isTtsIdle) {
        return _queue.removeAt(0);
      }
      return null;
    }

    // P2 Info spoken strictly when speech is idle
    if (top.priority == AlertPriority.p2Info) {
      if (isTtsIdle) {
        return _queue.removeAt(0);
      }
      return null;
    }

    return null;
  }

  /// P0 Danger handler: flushes lower priority items, interrupts active speech,
  /// and places the danger item at the top of the queue.
  void _handleP0Danger(AlertItem item, DateTime currentTime) {
    // Flush lower-priority items (P1, P2) from queue
    _queue.removeWhere((e) => e.priority != AlertPriority.p0Danger);

    // Insert at front
    _queue.insert(0, item);

    // Record history
    _recordHistory(item.cooldownKey, currentTime, item.distanceCm);

    // Trigger danger callback (interrupts TTS, triggers heavy vibration)
    onP0DangerTriggered?.call(item);
  }

  /// Checks if a new distance reading is significantly closer to override cooldown.
  /// Overrides if:
  /// - Obstacle moved closer by >= 30cm, OR
  /// - Distance reduced by >= 20% compared to previous reading.
  bool _checkDistanceOverride({double? lastDistance, double? newDistance}) {
    if (lastDistance == null || newDistance == null) return false;
    if (newDistance >= lastDistance) return false; // Moving away or same

    final absoluteDelta = lastDistance - newDistance;
    final relativeRatio = newDistance / lastDistance;

    return absoluteDelta >= 30.0 || relativeRatio <= 0.80;
  }

  void _recordHistory(String key, DateTime time, double? distance) {
    _history[key] = _AlertHistoryRecord(
      timestamp: time,
      distanceCm: distance,
    );
  }

  void _insertSorted(AlertItem item) {
    int index = 0;
    while (index < _queue.length &&
        _queue[index].priority.level <= item.priority.level) {
      index++;
    }
    _queue.insert(index, item);
  }

  /// Purges stale P1 navigation items whose timeout has elapsed.
  void _purgeExpired(DateTime now) {
    _queue.removeWhere((item) => item.isExpired(now));
  }

  /// Removes all items from the queue and resets history (e.g. on session end).
  void clear() {
    _queue.clear();
    _history.clear();
  }

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  List<AlertItem> get queuedItems => UnmodifiableListView(_queue);
}
