import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/habit_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';

class UpcomingItem {
  UpcomingItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.whenMs,
    required this.subtitle,
  });

  final String kind;
  final String id;
  final String title;
  final int whenMs;
  final String subtitle;
}

/// Cross-domain upcoming: tasks, bills, appointments, habits, routines.
class UpcomingService {
  UpcomingService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<List<UpcomingItem>> build({int days = 14, int limit = 40}) async {
    final items = <UpcomingItem>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final end = now + Duration(days: days).inMilliseconds;

    final tasks = TaskRepository(_db);
    for (final t in await tasks.listOpen()) {
      final due = t.dueAt;
      final start = t.scheduledStart;
      final when = due ?? start;
      if (when == null) continue;
      if (when < now - const Duration(days: 1).inMilliseconds) continue;
      if (when > end) continue;
      items.add(UpcomingItem(
        kind: 'task',
        id: t.id,
        title: t.title,
        whenMs: when,
        subtitle: due != null ? 'Task due' : 'Scheduled session',
      ));
    }

    for (final o in await BillRepository(_db).listOpenOccurrences()) {
      if (o.dueAt > end) continue;
      items.add(UpcomingItem(
        kind: 'bill',
        id: o.id,
        title: o.billName ?? 'Bill',
        whenMs: o.dueAt,
        subtitle: 'Bill payment',
      ));
    }

    final ext = ExtendedRepository(_db);
    for (final e in await ext.listUpcomingAppointments(days: days)) {
      final start = e['start_at'] as int? ?? now;
      items.add(UpcomingItem(
        kind: 'appointment',
        id: '${e['id']}',
        title: '${e['title']}',
        whenMs: start,
        subtitle: 'Appointment',
      ));
    }

    // Today's open habits / routines as near-term
    final dayStart = AppDatabase.startOfTodayMs();
    final habits = HabitRepository(_db);
    await habits.ensureAllTodayOccurrences();
    for (final h in await habits.listActive()) {
      final st = await habits.todayStatus(h.id);
      if (st == null || st == 'EXPECTED' || st == 'PARTIAL') {
        items.add(UpcomingItem(
          kind: 'habit',
          id: h.id,
          title: h.title,
          whenMs: dayStart + const Duration(hours: 18).inMilliseconds,
          subtitle: 'Habit today',
        ));
      }
    }

    final routines = RoutineRepository(_db);
    await routines.ensureAllTodayOccurrences();
    for (final r in await routines.listActive()) {
      final st = await routines.todayStatus(r.id);
      if (st == null || st == 'EXPECTED' || st == 'STARTED') {
        items.add(UpcomingItem(
          kind: 'routine',
          id: r.id,
          title: r.name,
          whenMs: dayStart + const Duration(hours: 8).inMilliseconds,
          subtitle: 'Routine today',
        ));
      }
    }

    items.sort((a, b) => a.whenMs.compareTo(b.whenMs));
    return items.take(limit).toList();
  }
}
