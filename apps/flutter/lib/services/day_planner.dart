import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/planning_repository.dart';
import '../data/task_repository.dart';
import 'query_cache.dart';

enum PlanItemKind { overdueTask, dueTodayTask, openTask, habit, bill, event }

class PlanItem {
  PlanItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.score,
    required this.reason,
    this.subtitle,
  });

  final PlanItemKind kind;
  final String id;
  final String title;
  final int score;
  final String reason;
  final String? subtitle;
}

/// Ranked "what should I do now" from local SQLite state.
class DayPlanner {
  DayPlanner({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<List<PlanItem>> buildPlan({int limit = 8}) async {
      /// Back-compat used by PlanningScreen.
  Future<List<PlanItem>> rankForToday({int limit = 8}) => buildPlan(limit: limit);
    return QueryCache.instance.getOrLoad(
      'day_plan_$limit',
      () => _build(limit),
      ttl: const Duration(seconds: 6),
    );
  }

  Future<List<PlanItem>> _build(int limit) async {
    final tasks = TaskRepository(_db);
    final habits = HabitRepository(_db);
    final bills = BillRepository(_db);

    final results = await Future.wait([
      tasks.listOverdue(),
      tasks.listDueToday(),
      tasks.listOpen(),
      habits.listActive(),
      bills.listOpenOccurrences(),
    ]);

    final overdue = results[0] as dynamic;
    final dueToday = results[1] as dynamic;
    final open = results[2] as dynamic;
    final activeHabits = results[3] as dynamic;
    final billOcc = results[4] as dynamic;

    final items = <PlanItem>[];
    final hour = DateTime.now().hour;

    for (final t in overdue) {
      items.add(PlanItem(
        kind: PlanItemKind.overdueTask,
        id: t.id,
        title: t.title,
        score: (100 + t.priority * 5).toInt(),
        reason: 'Overdue',
      ));
    }

    for (final t in dueToday) {
      if (items.any((i) => i.id == t.id)) continue;
      items.add(PlanItem(
        kind: PlanItemKind.dueTodayTask,
        id: t.id,
        title: t.title,
        score: (80 + t.priority * 4).toInt(),
        reason: 'Due today',
      ));
    }

    for (final o in billOcc.take(5)) {
      final dueBoost = o.dueAt <= AppDatabase.endOfTodayMs() ? 25 : 0;
      items.add(PlanItem(
        kind: PlanItemKind.bill,
        id: o.id,
        title: o.billName ?? 'Bill',
        score: 70 + dueBoost,
        reason: dueBoost > 0 ? 'Bill due / overdue' : 'Open bill',
        subtitle: o.expectedAmountMinor != null
            ? (o.expectedAmountMinor! / 100).toStringAsFixed(0)
            : null,
      ));
    }

    final habitBoost = (hour >= 6 && hour <= 10) || (hour >= 18 && hour <= 21) ? 15 : 0;
    for (final h in activeHabits.take(6)) {
      items.add(PlanItem(
        kind: PlanItemKind.habit,
        id: h.id,
        title: h.title,
        score: 50 + habitBoost,
        reason: 'Habit',
      ));
    }

    for (final t in open.take(12)) {
      if (items.any((i) => i.id == t.id)) continue;
      items.add(PlanItem(
        kind: PlanItemKind.openTask,
        id: t.id,
        title: t.title,
        score: (40 + t.priority * 3).toInt(),
        reason: t.status,
      ));
    }

    items.sort((a, b) => b.score.compareTo(a.score));
    return items.take(limit).toList();
  }

  Future<String> planNarrative({int limit = 5}) async {
    final plan = await buildPlan(limit: limit);
    final free = await PlanningRepository(_db).availableMinutes(day: DateTime.now());
    final hours = free ~/ 60;
    final mins = free % 60;
    if (plan.isEmpty) {
      return 'Nothing urgent ranked. Free window ≈ ${hours}h ${mins}m today.\nOpen Plan under Life to book sessions.';
    }
    final buf = StringBuffer()
      ..writeln('Free time today ≈ ${hours}h ${mins}m (8–22).')
      ..writeln('Suggested order:');
    for (var i = 0; i < plan.length; i++) {
      final p = plan[i];
      buf.writeln('${i + 1}. [${p.reason}] ${p.title}');
    }
    buf.writeln('(Overdue → due → bills → habits → backlog · book in Plan)');
    return buf.toString();
  }
}

/// Back-compat aliases used by PlanningScreen.
typedef DayPlannerService = DayPlanner;
typedef PrioritizedItem = PlanItem;
