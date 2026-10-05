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
    if (ms <= 0) return 'Earlier';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final wd = weekdays[d.weekday - 1];
    if (diff < 7) return wd;
    return '$wd, ${d.day} ${months[d.month - 1]}';
  }

  static String formatTime(int ms) {
    if (ms <= 0) return '';
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
      case 'TASK_SCHEDULED':
        return q == null ? 'Scheduled work' : 'Scheduled $q';
      case 'TASK_RESCHEDULED':
        return q == null ? 'Rescheduled a task' : 'Rescheduled $q';
      case 'TASK_UPDATED':
        return q == null ? 'Updated a task' : 'Updated $q';
      case 'TASK_REOPENED':
        return q == null ? 'Reopened a task' : 'Reopened $q';
      case 'TASK_DELETED':
        return q == null ? 'Removed a task' : 'Removed $q';
      case 'WORK_STARTED':
        return q == null ? 'Started a work session' : 'Started session on $q';
      case 'WORK_COMPLETED':
        return q == null ? 'Finished a work session' : 'Worked on $q';
      case 'WORK_PAUSED':
        return 'Paused work';
      case 'WORK_RESUMED':
        return 'Resumed work';
      case 'PROJECT_CREATED':
        return q == null ? 'Started a project' : 'Started project $q';
      case 'PROJECT_COMPLETED':
        return q == null ? 'Finished a project' : 'Finished project $q';
      case 'GOAL_CREATED':
        return q == null ? 'Set a goal' : 'Set goal $q';
      case 'GOAL_COMPLETED':
        return q == null ? 'Achieved a goal' : 'Achieved goal $q';
      case 'MILESTONE_COMPLETED':
        return q == null ? 'Reached a milestone' : 'Reached milestone $q';
      case 'MILESTONE_CREATED':
        return q == null ? 'Added a milestone' : 'Added milestone $q';
      case 'HABIT_COMPLETED':
        return q == null ? 'Completed a habit' : 'Completed habit $q';
      case 'HABIT_SKIPPED':
        return q == null ? 'Skipped a habit' : 'Skipped habit $q';
      case 'HABIT_CREATED':
        return q == null ? 'Started a habit' : 'Started habit $q';
      case 'ROUTINE_COMPLETED':
        return q == null ? 'Finished a routine' : 'Finished $q';
      case 'ROUTINE_MISSED':
        return q == null ? 'Missed a routine' : 'Missed $q';
      case 'ROUTINE_RECOVERED':
        return q == null ? 'Caught up a routine' : 'Caught up on $q';
      case 'BILL_PAID':
        return q == null ? 'Paid a bill' : 'Paid $q';
      case 'BILL_CREATED':
        return q == null ? 'Added a bill' : 'Added bill $q';
      case 'EXPENSE_RECORDED':
        return q == null ? 'Recorded an expense' : 'Spent on $q';
      case 'INCOME_RECORDED':
        return q == null ? 'Recorded income' : 'Received: $q';
      case 'DEBT_PAYMENT_RECORDED':
        return q == null ? 'Made a debt payment' : 'Debt payment — $q';
      case 'DEBT_PAID_OFF':
        return q == null ? 'Cleared a debt' : 'Cleared debt $q';
      case 'SAVINGS_CONTRIBUTION_RECORDED':
        return q == null ? 'Saved money' : 'Saved toward $q';
      case 'SAVINGS_GOAL_REACHED':
        return q == null ? 'Reached a savings goal' : 'Reached savings goal $q';
      case 'SUBSCRIPTION_PAID':
        return q == null ? 'Paid a subscription' : 'Paid subscription $q';
      case 'SUBSCRIPTION_CREATED':
        return q == null ? 'Added a subscription' : 'Added subscription $q';
      case 'NOTE_CREATED':
        return q == null ? 'Wrote a note' : 'Noted: $q';
      case 'NOTE_UPDATED':
        return q == null ? 'Updated a note' : 'Updated note $q';
      case 'PRACTICAL_COMPLETED':
        return q == null ? 'Finished a practical item' : 'Finished $q';
      case 'DOCUMENT_RENEWED':
        return q == null ? 'Renewed a document' : 'Renewed $q';
      case 'TIME_BLOCK_CREATED':
        return q == null ? 'Blocked time' : 'Blocked time for $q';
      case 'REMINDER_CREATED':
        return q == null ? 'Set a reminder' : 'Reminder: $q';
      case 'WELLNESS_CHECKIN':
        return 'Wellness check-in';
      case 'BUDGET_CREATED':
        return q == null ? 'Set a budget' : 'Set budget $q';
      default:
        if (type.startsWith('TASK_CREATED_FROM_')) {
          return q == null
              ? 'Created a task from life item'
              : 'Created task $q from life item';
        }
        final soft = type.replaceAll('_', ' ').toLowerCase();
        return q == null ? soft : '$soft — $q';
    }
  }

  String? _detail(String type, String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    try {
      if (metadata.contains('actualMinutes') || metadata.contains('minutes')) {
        final m =
            RegExp(r'"(?:actualMinutes|minutes)"\s*:\s*(\d+)').firstMatch(metadata);
        final p = RegExp(r'"plannedMinutes"\s*:\s*(\d+)').firstMatch(metadata);
        if (m != null) {
          final a = m.group(1);
          final pl = p?.group(1);
          return pl == null ? '${a}m of focused work' : '${a}m worked (planned ${pl}m)';
        }
      }
      if (metadata.contains('amount')) {
        final m = RegExp(r'"amount"\s*:\s*(\d+)').firstMatch(metadata);
        if (m != null) {
          final minor = int.tryParse(m.group(1)!);
          if (minor != null) {
            final major =
                (minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2);
            if (type.contains('DEBT')) return '$major paid toward debt';
            if (type.contains('SAVINGS')) return '$major saved';
            if (type.contains('BILL') || type.contains('SUBSCRIPTION')) {
              return '$major paid';
            }
            if (type.contains('EXPENSE')) return '$major spent';
            if (type.contains('INCOME')) return '$major received';
            return '$major recorded';
          }
        }
      }
      if (metadata.contains('remaining')) {
        final m = RegExp(r'"remaining"\s*:\s*(\d+)').firstMatch(metadata);
        if (m != null) {
          final rem = int.tryParse(m.group(1)!);
          if (rem != null) {
            return rem == 0
                ? 'Fully paid off'
                : '${(rem / 100).toStringAsFixed(0)} still remaining';
          }
        }
      }
      if (metadata.contains('fromType')) {
        final m =
            RegExp(r'"fromType"\s*:\s*"([^"]+)"').firstMatch(metadata);
        if (m != null) return 'Linked from ${m.group(1)!.toLowerCase()}';
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveTitle(
      dynamic db, String entityType, String entityId) async {
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
