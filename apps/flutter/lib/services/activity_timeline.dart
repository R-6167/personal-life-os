import '../data/database.dart';

/// One row on the personal activity timeline.
class TimelineEntry {
  TimelineEntry({
    required this.id,
    required this.headline,
    required this.detail,
    required this.occurredAt,
    required this.eventType,
    required this.entityType,
    required this.entityId,
  });

  final String id;
  final String headline;
  final String detail;
  final int occurredAt;
  final String eventType;
  final String entityType;
  final String entityId;
}

/// Turns immutable activity_events into a readable life timeline.
class ActivityTimelineService {
  ActivityTimelineService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  static const _labels = <String, String>{
    'GOAL_CREATED': 'Created a goal',
    'GOAL_COMPLETED': 'Completed a goal',
    'PROJECT_CREATED': 'Started a project',
    'PROJECT_COMPLETED': 'Finished a project',
    'MILESTONE_COMPLETED': 'Reached a milestone',
    'TASK_CREATED': 'Added a task',
    'TASK_COMPLETED': 'Completed a task',
    'TASK_SCHEDULED': 'Scheduled a task',
    'HABIT_COMPLETED': 'Logged a habit',
    'HABIT_SKIPPED': 'Skipped a habit',
    'HABIT_MISSED': 'Missed a habit',
    'ROUTINE_COMPLETED': 'Finished a routine',
    'ROUTINE_MISSED': 'Missed a routine',
    'BILL_CREATED': 'Added a bill',
    'BILL_PAID': 'Paid a bill',
    'EXPENSE_RECORDED': 'Recorded an expense',
    'INCOME_RECORDED': 'Recorded income',
    'DEBT_PAYMENT_RECORDED': 'Made a debt payment',
    'SAVINGS_CONTRIBUTION_RECORDED': 'Contributed to savings',
    'BUDGET_CREATED': 'Set a budget',
    'WELLNESS_CHECKIN': 'Wellness check-in',
    'NOTE_CREATED': 'Wrote a note',
    'REMINDER_CREATED': 'Set a reminder',
  };

  Future<List<TimelineEntry>> build({int limit = 60}) async {
    final db = await _db.database;
    final rows = await db.query(
      'activity_events',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    final out = <TimelineEntry>[];
    for (final r in rows) {
      final type = '${r['event_type']}';
      final entityType = '${r['entity_type']}';
      final entityId = '${r['entity_id']}';
      final title = await _resolveTitle(db, entityType, entityId);
      final headline = _labels[type] ?? type.replaceAll('_', ' ').toLowerCase();
      final detail = [
        if (title != null) title,
        entityType.toLowerCase(),
        if (r['metadata'] != null) 'details recorded',
      ].join(' · ');
      out.add(TimelineEntry(
        id: '${r['id']}',
        headline: headline,
        detail: detail,
        occurredAt: (r['occurred_at'] as int?) ?? 0,
        eventType: type,
        entityType: entityType,
        entityId: entityId,
      ));
    }
    return out;
  }

  Future<String?> _resolveTitle(dynamic db, String entityType, String entityId) async {
    try {
      switch (entityType) {
        case 'GOAL':
          return _field(db, 'goals', entityId, 'title');
        case 'PROJECT':
          return _field(db, 'projects', entityId, 'title');
        case 'MILESTONE':
          return _field(db, 'milestones', entityId, 'title');
        case 'TASK':
          return _field(db, 'tasks', entityId, 'title');
        case 'HABIT':
          return _field(db, 'habits', entityId, 'title');
        case 'ROUTINE':
          return _field(db, 'routines', entityId, 'name');
        case 'BILL':
        case 'BILL_OCCURRENCE':
          if (entityType == 'BILL_OCCURRENCE') {
            final occ = await db.query('bill_occurrences',
                where: 'id = ?', whereArgs: [entityId], limit: 1);
            if (occ.isNotEmpty) {
              return _field(db, 'bills', '${occ.first['bill_id']}', 'name');
            }
          }
          return _field(db, 'bills', entityId, 'name');
        case 'EXPENSE':
          return _field(db, 'expenses', entityId, 'description');
        case 'INCOME':
          return _field(db, 'income', entityId, 'source');
        case 'NOTE':
          final c = await _field(db, 'notes', entityId, 'content');
          if (c == null) return null;
          return c.length > 48 ? '${c.substring(0, 48)}…' : c;
        case 'BUDGET':
          return _field(db, 'budgets', entityId, 'name');
        case 'SAVINGS_GOAL':
          return _field(db, 'savings_goals', entityId, 'name');
        case 'DEBT':
          return _field(db, 'debts', entityId, 'title');
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _field(dynamic db, String table, String id, String col) async {
    final rows = await db.query(table, columns: [col], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first[col]?.toString();
  }
}
