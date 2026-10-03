import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/habit_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';

enum AttentionKind {
  overdueTask,
  dueTask,
  habitPending,
  habitMissed,
  routinePending,
  routineMissed,
  billDue,
  documentExpiring,
  practicalDue,
  appointmentSoon,
  shoppingOpen,
}

class AttentionItem {
  AttentionItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.urgency,
  });

  final AttentionKind kind;
  final String id;
  final String title;
  final String subtitle;
  final int urgency; // higher = more urgent
}

/// Single ranked feed of recurring + practical responsibilities.
class NeedsAttentionService {
  NeedsAttentionService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<List<AttentionItem>> build({int limit = 40}) async {
    final items = <AttentionItem>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final week = now + const Duration(days: 14).inMilliseconds;

    final tasks = TaskRepository(_db);
    for (final t in await tasks.listOverdue()) {
      items.add(AttentionItem(
        kind: AttentionKind.overdueTask,
        id: t.id,
        title: t.title,
        subtitle: 'Overdue task',
        urgency: 100,
      ));
    }
    for (final t in await tasks.listDueToday()) {
      items.add(AttentionItem(
        kind: AttentionKind.dueTask,
        id: t.id,
        title: t.title,
        subtitle: 'Due today',
        urgency: 85,
      ));
    }

    final habits = HabitRepository(_db);
    await habits.markMissedBeforeToday();
    await habits.ensureAllTodayOccurrences();
    for (final h in await habits.listActive()) {
      final st = await habits.todayStatus(h.id);
      if (st == null || st == 'EXPECTED' || st == 'PARTIAL') {
        items.add(AttentionItem(
          kind: AttentionKind.habitPending,
          id: h.id,
          title: h.title,
          subtitle: 'Habit still open today',
          urgency: 70,
        ));
      }
    }

    final routines = RoutineRepository(_db);
    await routines.markMissedBeforeToday();
    await routines.ensureAllTodayOccurrences();
    for (final r in await routines.listActive()) {
      final st = await routines.todayStatus(r.id);
      if (st == null || st == 'EXPECTED' || st == 'STARTED') {
        items.add(AttentionItem(
          kind: AttentionKind.routinePending,
          id: r.id,
          title: r.name,
          subtitle: st == 'STARTED' ? 'Routine in progress' : 'Routine due today',
          urgency: 72,
        ));
      }
    }
    for (final m in await routines.listMissed(limit: 8)) {
      items.add(AttentionItem(
        kind: AttentionKind.routineMissed,
        id: m['id'] as String,
        title: '${m['routine_name']}',
        subtitle: 'Missed — recover when ready',
        urgency: 78,
      ));
    }

    final bills = BillRepository(_db);
    for (final o in await bills.listOpenOccurrences()) {
      final overdue = o.dueAt < now;
      items.add(AttentionItem(
        kind: AttentionKind.billDue,
        id: o.id,
        title: o.billName ?? 'Bill',
        subtitle: overdue ? 'Bill overdue' : 'Bill due',
        urgency: overdue ? 95 : 80,
      ));
    }

    final ext = ExtendedRepository(_db);
    for (final d in await ext.listDocuments()) {
      final exp = d['expires_at'] as int?;
      if (exp != null && exp <= week) {
        final days = ((exp - now) / Duration.millisecondsPerDay).ceil();
        items.add(AttentionItem(
          kind: AttentionKind.documentExpiring,
          id: d['id'] as String,
          title: '${d['title']}',
          subtitle: days < 0 ? 'Document expired' : 'Expires in $days day(s)',
          urgency: days < 0 ? 90 : 75,
        ));
      }
    }

    for (final p in await ext.listPractical()) {
      final due = p['due_at'] as int?;
      final exp = p['expires_at'] as int?;
      final when = due ?? exp;
      if (when != null && when <= week) {
        items.add(AttentionItem(
          kind: AttentionKind.practicalDue,
          id: p['id'] as String,
          title: '${p['title']}',
          subtitle: '${p['type']} needs attention',
          urgency: when < now ? 88 : 68,
        ));
      }
    }

    for (final e in await ext.listUpcomingAppointments(days: 3)) {
      items.add(AttentionItem(
        kind: AttentionKind.appointmentSoon,
        id: e['id'] as String,
        title: '${e['title']}',
        subtitle: 'Appointment soon',
        urgency: 76,
      ));
    }

    for (final s in await ext.listShoppingLists()) {
      items.add(AttentionItem(
        kind: AttentionKind.shoppingOpen,
        id: s['id'] as String,
        title: '${s['name']}',
        subtitle: 'Open shopping list',
        urgency: 40,
      ));
    }

    items.sort((a, b) => b.urgency.compareTo(a.urgency));
    return items.take(limit).toList();
  }
}
