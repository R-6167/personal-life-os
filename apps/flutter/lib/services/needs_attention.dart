import '../data/bill_repository.dart';
import '../data/budget_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';

enum AttentionSeverity {
  critical, // 🔴
  high, // 🟠
  medium, // 🟡
}

enum AttentionKind {
  overdueTask,
  dueTask,
  projectNoNextAction,
  habitPending,
  habitMissedStreak,
  routinePending,
  routineMissed,
  billOverdue,
  billDue,
  subscriptionRenewal,
  documentExpiring,
  documentExpired,
  practicalDue,
  vehicleService,
  warrantyExpiring,
  appointmentSoon,
  shoppingOpen,
  budgetWarning,
  budgetExceeded,
  debtOpen,
}

class AttentionItem {
  AttentionItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.urgency,
  });

  final AttentionKind kind;
  final String id;
  final String title;
  final String subtitle;
  final AttentionSeverity severity;
  final int urgency;

  String get badge {
    switch (severity) {
      case AttentionSeverity.critical:
        return '🔴';
      case AttentionSeverity.high:
        return '🟠';
      case AttentionSeverity.medium:
        return '🟡';
    }
  }
}

/// Defining Life OS feature: one ranked feed of what needs attention now.
class NeedsAttentionService {
  NeedsAttentionService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<List<AttentionItem>> build({int limit = 50}) async {
    final items = <AttentionItem>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final in7 = now + const Duration(days: 7).inMilliseconds;
    final in21 = now + const Duration(days: 21).inMilliseconds;
    final in30 = now + const Duration(days: 30).inMilliseconds;

    await _tasks(items, now);
    await _projects(items);
    await _habits(items);
    await _routines(items);
    await _bills(items, now);
    await _budgets(items);
    await _documents(items, now, in21);
    await _practical(items, now, in30);
    await _subscriptions(items, now, in7);
    await _debts(items);
    await _shopping(items);
    await _appointments(items, now, in7);

    items.sort((a, b) {
      final s = b.urgency.compareTo(a.urgency);
      if (s != 0) return s;
      return a.title.compareTo(b.title);
    });
    if (items.length > limit) return items.sublist(0, limit);
    return items;
  }

  Future<void> _tasks(List<AttentionItem> items, int now) async {
    final tasks = TaskRepository(_db);
    for (final t in await tasks.listOverdue()) {
      items.add(AttentionItem(
        kind: AttentionKind.overdueTask,
        id: t.id,
        title: t.title,
        subtitle: 'Overdue task',
        severity: AttentionSeverity.critical,
        urgency: 100,
      ));
    }
    for (final t in await tasks.listDueToday()) {
      if (t.isOverdue) continue;
      items.add(AttentionItem(
        kind: AttentionKind.dueTask,
        id: t.id,
        title: t.title,
        subtitle: 'Due today',
        severity: AttentionSeverity.high,
        urgency: 88,
      ));
    }
  }

  Future<void> _projects(List<AttentionItem> items) async {
    try {
      final projects = ProjectRepository(_db);
      final tasks = TaskRepository(_db);
      for (final p in await projects.listActive()) {
        final open = await tasks.listByProject(p.id);
        final openActive = open.where((t) =>
            t.status != EntityStatus.completed &&
            t.status != EntityStatus.cancelled);
        if (openActive.isEmpty) {
          items.add(AttentionItem(
            kind: AttentionKind.projectNoNextAction,
            id: p.id,
            title: p.title,
            subtitle: 'Project has no next task',
            severity: AttentionSeverity.medium,
            urgency: 65,
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _habits(List<AttentionItem> items) async {
    final habits = HabitRepository(_db);
    try {
      await habits.markMissedBeforeToday();
      await habits.ensureAllTodayOccurrences();
    } catch (_) {}
    for (final h in await habits.listActive()) {
      final st = await habits.todayStatus(h.id);
      if (st == null || st == HabitOccurrenceStatus.expected || st == 'PARTIAL') {
        items.add(AttentionItem(
          kind: AttentionKind.habitPending,
          id: h.id,
          title: h.title,
          subtitle: 'Habit still open today',
          severity: AttentionSeverity.medium,
          urgency: 70,
        ));
      }
      // Missed streak
      try {
        final recent = await habits.recentOccurrences(h.id, limit: 10);
        var miss = 0;
        for (final r in recent) {
          final s = '${r['status']}';
          if (s == HabitOccurrenceStatus.missed || s == 'MISSED') {
            miss++;
          } else if (s == HabitOccurrenceStatus.completed || s == 'COMPLETED') {
            break;
          }
        }
        if (miss >= 3) {
          items.add(AttentionItem(
            kind: AttentionKind.habitMissedStreak,
            id: h.id,
            title: h.title,
            subtitle: 'Habit missed $miss times',
            severity: AttentionSeverity.high,
            urgency: 82,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _routines(List<AttentionItem> items) async {
    final routines = RoutineRepository(_db);
    try {
      await routines.markMissedBeforeToday();
      await routines.ensureAllTodayOccurrences();
    } catch (_) {}
    for (final r in await routines.listActive()) {
      final st = await routines.todayStatus(r.id);
      if (st == null || st == 'EXPECTED' || st == 'STARTED') {
        items.add(AttentionItem(
          kind: AttentionKind.routinePending,
          id: r.id,
          title: r.name,
          subtitle: st == 'STARTED' ? 'Routine in progress' : 'Routine due today',
          severity: AttentionSeverity.medium,
          urgency: 72,
        ));
      }
    }
    try {
      for (final m in await routines.listMissed(limit: 8)) {
        items.add(AttentionItem(
          kind: AttentionKind.routineMissed,
          id: m['id'] as String,
          title: '${m['routine_name']}',
          subtitle: 'Missed — recover when ready',
          severity: AttentionSeverity.high,
          urgency: 78,
        ));
      }
    } catch (_) {}
  }

  Future<void> _bills(List<AttentionItem> items, int now) async {
    final bills = BillRepository(_db);
    for (final o in await bills.listOpenOccurrences()) {
      final overdue = o.dueAt < now;
      items.add(AttentionItem(
        kind: overdue ? AttentionKind.billOverdue : AttentionKind.billDue,
        id: o.id,
        title: o.billName ?? 'Bill',
        subtitle: overdue ? 'Bill overdue' : 'Bill due',
        severity: overdue ? AttentionSeverity.critical : AttentionSeverity.high,
        urgency: overdue ? 98 : 84,
      ));
    }
  }

  Future<void> _budgets(List<AttentionItem> items) async {
    try {
      for (final b in await BudgetRepository(_db).alerts()) {
        final spent = (b.spentMinor / 100).toStringAsFixed(0);
        final limit = (b.limitMinor / 100).toStringAsFixed(0);
        if (b.level == BudgetAlertLevel.exceeded) {
          items.add(AttentionItem(
            kind: AttentionKind.budgetExceeded,
            id: b.id,
            title: b.name,
            subtitle: 'Budget exceeded ($spent / $limit ${Defaults.currency})',
            severity: AttentionSeverity.critical,
            urgency: 92,
          ));
        } else {
          items.add(AttentionItem(
            kind: AttentionKind.budgetWarning,
            id: b.id,
            title: b.name,
            subtitle: 'Near budget limit ($spent / $limit ${Defaults.currency})',
            severity: AttentionSeverity.high,
            urgency: 74,
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _documents(List<AttentionItem> items, int now, int in21) async {
    final ext = ExtendedRepository(_db);
    for (final d in await ext.listDocuments()) {
      final exp = d['expires_at'] as int?;
      if (exp == null) continue;
      final title = '${d['title']}';
      final days = ((exp - now) / Duration.millisecondsPerDay).ceil();
      if (exp < now) {
        items.add(AttentionItem(
          kind: AttentionKind.documentExpired,
          id: d['id'] as String,
          title: title,
          subtitle: 'Document expired',
          severity: AttentionSeverity.critical,
          urgency: 96,
        ));
      } else if (exp <= in21) {
        items.add(AttentionItem(
          kind: AttentionKind.documentExpiring,
          id: d['id'] as String,
          title: title,
          subtitle: days <= 0 ? 'Expires today' : 'Expires in $days days',
          severity: days <= 7 ? AttentionSeverity.high : AttentionSeverity.medium,
          urgency: days <= 7 ? 86 : 68,
        ));
      }
    }
  }

  Future<void> _practical(List<AttentionItem> items, int now, int in30) async {
    final ext = ExtendedRepository(_db);
    for (final p in await ext.listPractical()) {
      final due = p['due_at'] as int?;
      if (due == null) continue;
      final title = '${p['title']}';
      final kind = ('${p['kind'] ?? ''}').toUpperCase();
      final days = ((due - now) / Duration.millisecondsPerDay).ceil();
      final overdue = due < now;

      AttentionKind ak = AttentionKind.practicalDue;
      if (kind.contains('VEHICLE') || kind.contains('SERVICE') || kind.contains('CAR')) {
        ak = AttentionKind.vehicleService;
      } else if (kind.contains('WARRANTY')) {
        ak = AttentionKind.warrantyExpiring;
      }

      String sub;
      if (overdue) {
        sub = ak == AttentionKind.vehicleService ? 'Service overdue' : 'Due — overdue';
      } else if (days <= 0) {
        sub = 'Due today';
      } else {
        sub = 'Due in $days days';
      }

      if (overdue || due <= in30) {
        items.add(AttentionItem(
          kind: ak,
          id: p['id'] as String,
          title: title,
          subtitle: sub,
          severity: overdue
              ? AttentionSeverity.high
              : (days <= 7 ? AttentionSeverity.high : AttentionSeverity.medium),
          urgency: overdue ? 90 : (days <= 7 ? 76 : 60),
        ));
      }
    }
  }

  Future<void> _subscriptions(List<AttentionItem> items, int now, int in7) async {
    final ext = ExtendedRepository(_db);
    try {
      for (final s in await ext.listSubscriptions()) {
        final next = s['next_renewal_at'] as int?;
        if (next == null) continue;
        if (next > in7) continue;
        final name = '${s['service_name'] ?? s['name']}';
        final days = ((next - now) / Duration.millisecondsPerDay).ceil();
        items.add(AttentionItem(
          kind: AttentionKind.subscriptionRenewal,
          id: s['id'] as String,
          title: name,
          subtitle: next < now
              ? 'Subscription renewal overdue'
              : (days <= 0 ? 'Renews today' : 'Renews in $days days'),
          severity: next < now ? AttentionSeverity.high : AttentionSeverity.medium,
          urgency: next < now ? 83 : 66,
        ));
      }
    } catch (_) {}
  }

  Future<void> _debts(List<AttentionItem> items) async {
    try {
      for (final d in await ExtendedRepository(_db).listDebts()) {
        final rem = (d['remaining_amount_minor'] as int?) ?? 0;
        if (rem <= 0) continue;
        if (d['direction'] != 'OWED_BY_ME') continue;
        items.add(AttentionItem(
          kind: AttentionKind.debtOpen,
          id: d['id'] as String,
          title: '${d['title']}',
          subtitle: 'Open debt — ${(rem / 100).toStringAsFixed(0)} ${Defaults.currency}',
          severity: AttentionSeverity.medium,
          urgency: 55,
        ));
      }
    } catch (_) {}
  }

  Future<void> _shopping(List<AttentionItem> items) async {
    try {
      for (final l in await ExtendedRepository(_db).listShoppingLists()) {
        items.add(AttentionItem(
          kind: AttentionKind.shoppingOpen,
          id: l['id'] as String,
          title: '${l['name']}',
          subtitle: 'Open shopping list',
          severity: AttentionSeverity.medium,
          urgency: 40,
        ));
      }
    } catch (_) {}
  }

  Future<void> _appointments(List<AttentionItem> items, int now, int in7) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'calendar_events',
        where: 'start_at >= ? AND start_at <= ?',
        whereArgs: [now, in7],
        orderBy: 'start_at ASC',
        limit: 12,
      );
      for (final e in rows) {
        final start = e['start_at'] as int? ?? 0;
        final hours = ((start - now) / Duration.millisecondsPerHour).round();
        items.add(AttentionItem(
          kind: AttentionKind.appointmentSoon,
          id: e['id'] as String,
          title: '${e['title']}',
          subtitle: hours < 24
              ? (hours <= 0 ? 'Appointment now' : 'In ~$hours hours')
              : 'Appointment within a week',
          severity: hours <= 24 ? AttentionSeverity.high : AttentionSeverity.medium,
          urgency: hours <= 24 ? 87 : 62,
        ));
      }
    } catch (_) {}
  }
}
