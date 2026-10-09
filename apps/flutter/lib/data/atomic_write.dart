import 'package:sqflite/sqflite.dart';

import '../domain/enums.dart';
import 'database.dart';

/// Principle: meaningful state change + activity event must commit together.
///
/// Usage:
/// ```dart
/// await AtomicWrite.run(
///   state: (txn) async { await txn.update(...); },
///   eventType: 'TASK_COMPLETED',
///   entityType: 'TASK',
///   entityId: id,
/// );
/// ```
class AtomicWrite {
  AtomicWrite._();

  /// Run [state] and insert one activity event in the same SQLite transaction.
  static Future<T> run<T>({
    required Future<T> Function(Transaction txn) state,
    required String eventType,
    required String entityType,
    required String entityId,
    String source = EventSource.user,
    String? metadata,
    int? occurredAt,
    List<AtomicEvent> additionalEvents = const [],
    AppDatabase? db,
  }) async {
    final database = db ?? AppDatabase.instance;
    final ownerId = await database.requireOwnerId();
    final now = occurredAt ?? AppDatabase.nowMs();

    return database.txn((txn) async {
      final result = await state(txn);
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': eventType,
        'entity_type': entityType,
        'entity_id': entityId,
        'occurred_at': now,
        'recorded_at': AppDatabase.nowMs(),
        'source': source,
        if (metadata != null) 'metadata': metadata,
      });
      for (final event in additionalEvents) {
        await txn.insert('activity_events', {
          'id': AppDatabase.newId(), 'owner_id': ownerId,
          'event_type': event.eventType, 'entity_type': event.entityType, 'entity_id': event.entityId,
          'occurred_at': event.occurredAt ?? now, 'recorded_at': AppDatabase.nowMs(), 'source': event.source,
          if (event.metadata != null) 'metadata': event.metadata,
        });
      }
      return result;
    });
  }

  /// Multiple events with one state mutation (still one transaction).
  static Future<T> runWithEvents<T>({
    required Future<T> Function(Transaction txn) state,
    required List<AtomicEvent> events,
    AppDatabase? db,
  }) async {
    final database = db ?? AppDatabase.instance;
    final ownerId = await database.requireOwnerId();
    final recorded = AppDatabase.nowMs();

    return database.txn((txn) async {
      final result = await state(txn);
      for (final e in events) {
        await txn.insert('activity_events', {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'event_type': e.eventType,
          'entity_type': e.entityType,
          'entity_id': e.entityId,
          'occurred_at': e.occurredAt ?? recorded,
          'recorded_at': recorded,
          'source': e.source,
          if (e.metadata != null) 'metadata': e.metadata,
        });
      }
      return result;
    });
  }
}

class AtomicEvent {
  const AtomicEvent({
    required this.eventType,
    required this.entityType,
    required this.entityId,
    this.source = EventSource.user,
    this.metadata,
    this.occurredAt,
  });

  final String eventType;
  final String entityType;
  final String entityId;
  final String source;
  final String? metadata;
  final int? occurredAt;
}
