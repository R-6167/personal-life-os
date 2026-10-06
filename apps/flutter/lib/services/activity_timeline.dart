import '../data/database.dart';

/// One moment on the person's life timeline (not a raw event log).
class TimelineEntry {
  TimelineEntry({
    required this.id,
    required this.headline,
    this.detail,
    required this.occurredAt,
    required this.eventType,
    required this.entityType,
    required this.entityId,
  });

  final String id;
  final String headline;
  final String? detail;
  final int occurredAt;
  final String eventType;
  final String entityType;
  final String entityId;
}

class TimelineDayGroup {
  TimelineDayGroup({required this.label, required this.entries});
  final String label;
  final List<TimelineEntry> entries;
}

/// Historical memory layer: activity_events → readable life story.
class ActivityTimelineService {
  ActivityTimelineService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  static const _hidden = {
    'SMART_REMINDERS_SCHEDULED',
    'INTEGRITY',
    'APP_OPEN',
    'APP_RESUME',
    'APP_BACKGROUND',
  };

  Future<List<TimelineEntry>> build({int limit = 80}) async {
    final db = await _db.database;
    final rows = await db.query(
      'activity_events',
      orderBy: 'occurred_at DESC',
      limit: limit * 2,
    );
    final out = <TimelineEntry>[];
    for (final r in rows) {
      final type = '${r['event_type']}';
      if (_hidden.contains(type)) continue;
      if (type.startsWith('APP_')) continue;

      final entityType = '${r['entity_type']}';
      final entityId = '${r['entity_id']}';
      final title = await _resolveTitle(db, entityType, entityId);
      final headline = _headline(type, title);
      final detail = _detail(type, r['metadata'] as String?);

      out.add(TimelineEntry(
        id: '${r['id']}',
        headline: headline,
        detail: detail,
        occurredAt: (r['occurred_at'] as int?) ?? 0,
        eventType: type,
        entityType: entityType,
        entityId: entityId,
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  List<TimelineDayGroup> groupByDay(List<TimelineEntry> entries) {
    final map = <String, List<TimelineEntry>>{};
    final order = <String>[];
    for (final e in entries) {
      final label = _dayLabel(e.occurredAt);
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(e);
    }
    return [
      for (final label in order)
        TimelineDayGroup(label: label, entries: map[label]!),
    ];
  }

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _headline(String type, String? title) {
    final q = title == null || title.isEmpty ? null : '"$title"';
    switch (type) {
      case 'TASK_COMPLETED':
        return q == null ? 'Completed a task' : 'Completed $q';
      case 'TASK_CREATED':
        return q == null ? 'Added a task' : 'Added task $q';
      case 'TASK_OCCURRENCE_SPAWNED':
        return q == null
            ? 'Next occurrence planned'
            : 'Next occurrence of $q planned';
      case 'TASK_SCHEDULED':
        return q == null ? 'Scheduled work' : 'Scheduled $q';
      case 'TASK_RESCHEDULED':
        return q == null ? 'Rescheduled a task' : 'Rescheduled $q';
      case 'TASK_UPDATED':
        return q == null ? 'Updated a task' : 'Updated $q';
      case 'TASK_REOPENED':
        return q == null ? 'Reopened a task' : 'Reopened $q';
      case 'TASK_DELETED':
      case 'TASK_CANCELLED':
        return q == null ? 'Removed a task' : 'Removed $q';
      case 'WORK_STARTED':
        return q == null ? 'Started working' : 'Started work on $q';
      case 'WORK_ENDED':
      case 'WORK_COMPLETED':
        return q == null ? 'Finished a work session' : 'Finished work on $q';
      case 'EXPENSE_RECORDED':
        return q == null ? 'Recorded an expense' : 'Spent on $q';
      case 'INCOME_RECORDED':
        return q == null ? 'Recorded income' : 'Income: $q';
      case 'BILL_PAID':
        return q == null ? 'Paid a bill' : 'Paid $q';
      case 'DEBT_PAYMENT_RECORDED':
        return q == null ? 'Made a debt payment' : 'Debt payment: $q';
      case 'SAVINGS_CONTRIBUTION_RECORDED':
        return q == null ? 'Saved toward a goal' : 'Saved toward $q';
      case 'SAVINGS_GOAL_REACHED':
        return q == null ? 'Reached a savings goal' : 'Reached $q';
      case 'SUBSCRIPTION_RENEWED':
        return q == null ? 'Subscription renewed' : 'Renewed $q';
      case 'HABIT_COMPLETED':
        return q == null ? 'Completed a habit' : 'Habit: $q';
      case 'NOTE_CREATED':
        return q == null ? 'Wrote a note' : 'Note: $q';
      case 'GOAL_CREATED':
        return q == null ? 'Set a goal' : 'Goal: $q';
      case 'PROJECT_CREATED':
        return q == null ? 'Started a project' : 'Project: $q';
      default:
        if (type.contains('COMPLETED')) {
          return q == null ? 'Completed something' : 'Completed $q';
        }
        if (type.contains('CREATED')) {
          return q == null ? 'Created something' : 'Created $q';
        }
        return type.replaceAll('_', ' ').toLowerCase();
    }
  }

  String? _detail(String type, String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    return null;
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
        case 'WORK_SESSION':
          final sid = await _field(db, 'work_sessions', entityId, 'task_id');
          if (sid != null) return _field(db, 'tasks', sid, 'title');
          return null;
        case 'HABIT':
          return _field(db, 'habits', entityId, 'title');
        case 'ROUTINE':
          return _field(db, 'routines', entityId, 'name');
        case 'BILL':
          return _field(db, 'bills', entityId, 'name');
        case 'BILL_OCCURRENCE':
          final occ = await db.query('bill_occurrences',
              where: 'id = ?', whereArgs: [entityId], limit: 1);
          if (occ.isNotEmpty) {
            return _field(db, 'bills', '${occ.first['bill_id']}', 'name');
          }
          return null;
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
        case 'SUBSCRIPTION':
          return _field(db, 'subscriptions', entityId, 'service_name');
        case 'PRACTICAL':
          return _field(db, 'practical_items', entityId, 'title');
        case 'DOCUMENT':
          return _field(db, 'documents', entityId, 'title');
        case 'ACCOUNT':
        case 'FINANCIAL_ACCOUNT':
          return _field(db, 'financial_accounts', entityId, 'name');
        case 'REMINDER':
          return _field(db, 'reminders', entityId, 'title');
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _field(dynamic db, String table, String id, String col) async {
    final rows =
        await db.query(table, columns: [col], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first[col]?.toString();
  }
}
