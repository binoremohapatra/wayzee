import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/domain/alerts/alert_queue.dart';
import 'package:wayze/domain/models/alert_item.dart';
import 'package:wayze/domain/models/spatial_zone.dart';

void main() {
  group('AlertQueue Tests', () {
    late AlertQueue queue;

    setUp(() {
      queue = AlertQueue(
        cooldownDuration: const Duration(seconds: 3),
        p1StaleDuration: const Duration(seconds: 2),
      );
    });

    test('Enqueue respects priority order: P0 > P1 > P2', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

      final p2 = AlertItem(
        id: '1',
        text: 'Door on your right',
        priority: AlertPriority.p2Info,
        classification: 'door',
        zone: SpatialZone.right,
        createdAt: baseTime,
      );

      final p1 = AlertItem(
        id: '2',
        text: 'Turn left in 3 steps',
        priority: AlertPriority.p1Navigation,
        classification: 'turn',
        zone: SpatialZone.left,
        createdAt: baseTime,
      );

      queue.enqueue(p2, now: baseTime);
      queue.enqueue(p1, now: baseTime);

      // P1 must be polled before P2
      final firstPolled = queue.pollNext(isTtsIdle: true, now: baseTime);
      expect(firstPolled?.id, equals('2'));
      expect(firstPolled?.priority, equals(AlertPriority.p1Navigation));

      final secondPolled = queue.pollNext(isTtsIdle: true, now: baseTime);
      expect(secondPolled?.id, equals('1'));
      expect(secondPolled?.priority, equals(AlertPriority.p2Info));
    });

    test('P0 Danger flushes lower priority items and triggers danger callback', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      AlertItem? triggeredDanger;

      queue = AlertQueue(
        onP0DangerTriggered: (danger) {
          triggeredDanger = danger;
        },
      );

      // Enqueue P1 and P2 items
      queue.enqueue(AlertItem(
        id: 'nav1',
        text: 'Continue straight',
        priority: AlertPriority.p1Navigation,
        classification: 'straight',
        createdAt: baseTime,
      ), now: baseTime);

      queue.enqueue(AlertItem(
        id: 'info1',
        text: 'Chair on left',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.left,
        createdAt: baseTime,
      ), now: baseTime);

      expect(queue.length, equals(2));

      // Enqueue P0 Danger
      final dangerItem = AlertItem(
        id: 'danger1',
        text: 'Stairs down ahead. Stop.',
        priority: AlertPriority.p0Danger,
        classification: 'stairs',
        distanceCm: 45.0,
        createdAt: baseTime,
      );

      queue.enqueue(dangerItem, now: baseTime);

      // Queue must only contain P0 items (lower priorities flushed)
      expect(queue.length, equals(1));
      expect(triggeredDanger?.id, equals('danger1'));
      expect(queue.queuedItems.first.priority, equals(AlertPriority.p0Danger));

      // P0 poll delivers immediately even if TTS is busy
      final polled = queue.pollNext(isTtsIdle: false, now: baseTime);
      expect(polled?.id, equals('danger1'));
    });

    test('P1 Navigation expires after ~2s if stale', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      final navItem = AlertItem(
        id: 'nav_turn',
        text: 'Turn right at the junction',
        priority: AlertPriority.p1Navigation,
        classification: 'turn',
        createdAt: t0,
        timeout: const Duration(seconds: 2),
      );

      queue.enqueue(navItem, now: t0);

      // At 1.5s, item is still valid within the 2s timeout
      expect(queue.length, equals(1));

      // At 2.5s, item has expired (stale)
      final t2 = t0.add(const Duration(milliseconds: 2500));
      final polled = queue.pollNext(isTtsIdle: true, now: t2);

      expect(polled, isNull);
      expect(queue.isEmpty, isTrue);
    });

    test('P2 Info is spoken ONLY when speech synthesizer is idle', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

      final infoItem = AlertItem(
        id: 'info1',
        text: 'Water cooler on left',
        priority: AlertPriority.p2Info,
        classification: 'landmark',
        zone: SpatialZone.left,
        createdAt: baseTime,
      );

      queue.enqueue(infoItem, now: baseTime);

      // When TTS is speaking, P2 item is NOT polled
      final polledWhileBusy = queue.pollNext(isTtsIdle: false, now: baseTime);
      expect(polledWhileBusy, isNull);
      expect(queue.length, equals(1));

      // When TTS is idle, P2 item is polled
      final polledWhileIdle = queue.pollNext(isTtsIdle: true, now: baseTime);
      expect(polledWhileIdle?.id, equals('info1'));
      expect(queue.isEmpty, isTrue);
    });

    test('3-second cooldown suppresses repeated (class, zone) alerts', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      final item1 = AlertItem(
        id: 'chair_1',
        text: 'Chair ahead, 150 centimetres, centre.',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.center,
        distanceCm: 150.0,
        createdAt: t0,
      );

      // First alert accepted
      final accepted1 = queue.enqueue(item1, now: t0);
      expect(accepted1, isTrue);

      // 1.5s later: same class and zone with identical distance -> suppressed by 3s cooldown
      final t1 = t0.add(const Duration(milliseconds: 1500));
      final item2 = AlertItem(
        id: 'chair_2',
        text: 'Chair ahead, 150 centimetres, centre.',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.center,
        distanceCm: 150.0,
        createdAt: t1,
      );

      final accepted2 = queue.enqueue(item2, now: t1);
      expect(accepted2, isFalse);

      // 3.5s later: cooldown elapsed -> accepted
      final t2 = t0.add(const Duration(milliseconds: 3500));
      final item3 = AlertItem(
        id: 'chair_3',
        text: 'Chair ahead, 150 centimetres, centre.',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.center,
        distanceCm: 150.0,
        createdAt: t2,
      );

      final accepted3 = queue.enqueue(item3, now: t2);
      expect(accepted3, isTrue);
    });

    test('Distance change overrides active 3s cooldown when obstacle rapidly approaches', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Initial observation: Chair at 200cm
      final item1 = AlertItem(
        id: 'chair_initial',
        text: 'Chair ahead, 200 centimetres',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.center,
        distanceCm: 200.0,
        createdAt: t0,
      );
      expect(queue.enqueue(item1, now: t0), isTrue);

      // 1 second later (inside 3s cooldown), obstacle is now at 120cm (closer by 80cm / >20%)
      final t1 = t0.add(const Duration(seconds: 1));
      final itemEscalated = AlertItem(
        id: 'chair_approaching',
        text: 'Chair ahead, 120 centimetres',
        priority: AlertPriority.p2Info,
        classification: 'chair',
        zone: SpatialZone.center,
        distanceCm: 120.0,
        createdAt: t1,
      );

      // Distance reduction overrides cooldown!
      final accepted = queue.enqueue(itemEscalated, now: t1);
      expect(accepted, isTrue);
    });

    test('Repeat coalescing deduplicates identical unpolled queued items', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      final itemA = AlertItem(
        id: 'door_1',
        text: 'Door on your left',
        priority: AlertPriority.p2Info,
        classification: 'door',
        zone: SpatialZone.left,
        createdAt: t0,
      );

      final itemB = AlertItem(
        id: 'door_2',
        text: 'Door on your left',
        priority: AlertPriority.p2Info,
        classification: 'door',
        zone: SpatialZone.left,
        createdAt: t0.add(const Duration(milliseconds: 100)),
      );

      queue.enqueue(itemA, now: t0);
      expect(queue.length, equals(1));

      // Enqueue identical alert
      queue.enqueue(itemB, now: t0.add(const Duration(milliseconds: 100)));

      // Must be coalesced into single queue entry
      expect(queue.length, equals(1));
    });
  });
}
