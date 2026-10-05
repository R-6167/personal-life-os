import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/atomic_write.dart';
import 'package:ordin/domain/enums.dart';

/// Documents the integrity contract: state + activity_events in one txn.
void main() {
  group('AtomicWrite contract', () {
    test('AtomicEvent carries required identity fields', () {
      const e = AtomicEvent(
        eventType: 'TASK_COMPLETED',
        entityType: 'TASK',
        entityId: 'task-1',
        metadata: '{"ok":true}',
      );
      expect(e.eventType, 'TASK_COMPLETED');
      expect(e.entityType, 'TASK');
      expect(e.entityId, 'task-1');
      expect(e.source, EventSource.user);
      expect(e.metadata, isNotNull);
    });

    test('multi-event list can describe bill pay lifecycle', () {
      const events = [
        AtomicEvent(
          eventType: 'BILL_PAID',
          entityType: 'BILL_OCCURRENCE',
          entityId: 'occ-1',
        ),
        AtomicEvent(
          eventType: 'EXPENSE_CREATED',
          entityType: 'EXPENSE',
          entityId: 'exp-1',
        ),
        AtomicEvent(
          eventType: 'ACCOUNT_BALANCE_UPDATED',
          entityType: 'ACCOUNT',
          entityId: 'acc-1',
        ),
      ];
      expect(events.length, 3);
      expect(events.map((e) => e.eventType).toSet().length, 3);
    });
  });
}
