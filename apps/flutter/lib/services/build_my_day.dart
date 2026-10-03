import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/planning_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';
import '../domain/db_map.dart';
import '../domain/models.dart';

enum DaySlotKind {
  event,
  block,
  task,
  habit,
  routine,
  breakSlot,
  free,
}

/// One timed entry on the built day timeline.
class DaySlot {
  final DateTime start;
  final DateTime end;
  final String title;
  final DaySlotKind kind;
  final String? entityId;
  final String reason;
  final bool locked;
  final int priority;

  const DaySlot({
    required this.start,
    required this.end,
    required this.title,
    required this.kind,
    this.entityId,
    this.reason = '',
    this.locked = false,
    this.priority = 0,
  });

  int get minutes => end.difference(start).inMinutes;

  String get timeLabel {
    String t(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${t(start)}–${t(end)}';
  }
}

class FlexibleCandidate {
  final String id;
  final String title;
  final DaySlotKind kind;
  final int durationMin;
  final int score;
  final String reason;

  const FlexibleCandidate({
    required this.id,
    required this.title,
    required this.kind,
    required this.durationMin,
    required this.score,
    required this.reason,
  });
}

class BuiltDay {
  final DateTime day;
  final List<DaySlot> slots;
  final List<FlexibleCandidate> unplaced;
  final int freeMinutes;
  final int plannedMinutes;
  final int dayStartHour;
  final int dayEndHour;

  const BuiltDay({
    required this.day,
    required this.slots,
    required this.unplaced,
    required this.freeMinutes,
    required this.plannedMinutes,
    this.dayStartHour = 8,
    this.dayEndHour = 22,
  });

  List<DaySlot> get timeline =>
      slots.where((s) => s.kind != DaySlotKind.free).toList();
}

/// Builds a concrete timed day from calendar, blocks, tasks, habits, routines.
class BuildMyDayEngine {
  BuildMyDayEngine({AppDatabase? db})
      : _db = db ?? AppDatabase.instance,
        _plan = PlanningRepository(db ?? AppDatabase.instance),
        _tasks = TaskRepository(db ?? AppDatabase.instance),
        _habits = HabitRepository(db ?? AppDatabase.instance),
        _routines = RoutineRepository(db ?? AppDatabase.instance);

  final AppDatabase _db;
  final PlanningRepository _plan;
  final TaskRepository _tasks;
  final HabitRepository _habits;
  final RoutineRepository _routines;

  Future<BuiltDay> build({
    DateTime? day,
    int dayStartHour = 8,
    int dayEndHour = 22,
    bool includeLunchBreak = true,
    int maxFlexible = 12,
  }) async {
    final d = day ?? DateTime.now();
    final dayStart = DateTime(d.year, d.month, d.day, dayStartHour);
    final dayEnd = DateTime(d.year, d.month, d.day, dayEndHour);
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

    var workStart = dayStart;
    if (isToday && now.isAfter(workStart)) {
      final m = ((now.minute + 14) ~/ 15) * 15;
      workStart = DateTime(now.year, now.month, now.day, now.hour, 0)
          .add(Duration(minutes: m >= 60 ? 60 : m));
      if (m >= 60) workStart = workStart.add(const Duration(hours: 1));
    }

    final locked = await _collectLocked(d, dayStart, dayEnd);
    final candidates = await _collectFlexible(d, locked, maxFlexible);

    if (includeLunchBreak) {
      final lunchStart = DateTime(d.year, d.month, d.day, 12, 30);
      final lunchEnd = lunchStart.add(const Duration(minutes: 45));
      if (!_overlapsAny(locked, lunchStart, lunchEnd) &&
          !lunchEnd.isBefore(workStart) &&
          lunchStart.isBefore(dayEnd)) {
        locked.add(DaySlot(
          start: lunchStart.isBefore(workStart) ? workStart : lunchStart,
          end: lunchEnd,
          title: 'Lunch / break',
          kind: DaySlotKind.breakSlot,
          reason: 'Energy reset',
          locked: false,
          priority: 0,
        ));
      }
    }

    locked.sort((a, b) => a.start.compareTo(b.start));
    final gaps = _freeGaps(workStart, dayEnd, locked);

    final placed = <DaySlot>[...locked];
    final unplaced = <FlexibleCandidate>[];
    final usedIds = locked.map((s) => s.entityId).whereType<String>().toSet();

    for (final c in candidates) {
      if (usedIds.contains(c.id)) continue;
      final fit = _placeInGaps(gaps, c.durationMin);
      if (fit == null) {
        final largest = gaps.isEmpty
            ? 0
            : gaps.map((g) => g.$2.difference(g.$1).inMinutes).reduce((a, b) => a > b ? a : b);
        final why = largest > 0 && c.durationMin > largest
            ? 'Too long for free gaps'
            : 'No free slot large enough';
        unplaced.add(FlexibleCandidate(
          id: c.id,
          title: c.title,
          kind: c.kind,
          durationMin: c.durationMin,
          score: c.score,
          reason: why,
        ));
        continue;
      }
      placed.add(DaySlot(
        start: fit.$1,
        end: fit.$2,
        title: c.title,
        kind: c.kind,
        entityId: c.id,
        reason: c.reason,
        locked: false,
        priority: c.score,
      ));
      usedIds.add(c.id);
      _consumeGap(gaps, fit.$1, fit.$2);
    }

    final blockedIds = await _tasks.listBlockedTaskIds();
    final seenUnplaced = unplaced.map((u) => u.id).toSet();
    for (final id in blockedIds) {
      if (usedIds.contains(id) || seenUnplaced.contains(id)) continue;
      final task = await _tasks.getById(id);
      if (task == null || task.scheduledStart != null) continue;
      unplaced.add(FlexibleCandidate(
        id: task.id,
        title: task.title,
        kind: DaySlotKind.task,
        durationMin: (task.estimatedMinutes ?? 30).clamp(15, 180),
        score: 0,
        reason: 'Blocked by incomplete dependency',
      ));
    }

    placed.sort((a, b) => a.start.compareTo(b.start));

    var planned = 0;
    for (final s in placed) {
      if (s.kind != DaySlotKind.free) planned += s.minutes;
    }
    var free = 0;
    for (final g in gaps) {
      free += g.$2.difference(g.$1).inMinutes;
    }

    return BuiltDay(
      day: DateTime(d.year, d.month, d.day),
      slots: placed,
      unplaced: unplaced,
      freeMinutes: free,
      plannedMinutes: planned,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
  }

  Future<int> apply(BuiltDay built) async {
    final blocked = await _tasks.listBlockedTaskIds();
    var n = 0;
    for (final s in built.timeline) {
      if (s.locked) continue;
      if (s.kind == DaySlotKind.task && s.entityId != null) {
        if (blocked.contains(s.entityId)) continue;
        await _plan.scheduleTaskSession(
          taskId: s.entityId!,
          start: s.start,
          durationMinutes: s.minutes.clamp(15, 180),
          title: s.title,
        );
        n++;
      } else if (s.kind == DaySlotKind.habit && s.entityId != null) {
        await _plan.addFocusBlock(
          start: s.start,
          durationMinutes: s.minutes.clamp(10, 60),
          title: 'Habit: ${s.title}',
        );
        n++;
      } else if (s.kind == DaySlotKind.routine && s.entityId != null) {
        await _plan.addFocusBlock(
          start: s.start,
          durationMinutes: s.minutes.clamp(15, 120),
          title: 'Routine: ${s.title}',
        );
        n++;
      }
    }
    return n;
  }

  Future<List<DaySlot>> _collectLocked(
    DateTime d,
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final out = <DaySlot>[];
    final db = await _db.database;

    try {
      final events = await db.query(
        'calendar_events',
        where: 'start_at < ? AND end_at > ?',
        whereArgs: [dayEnd.millisecondsSinceEpoch, dayStart.millisecondsSinceEpoch],
      );
      for (final e in events) {
        if ('${e['status'] ?? ''}' == 'CANCELLED') continue;
        final s = DateTime.fromMillisecondsSinceEpoch(e['start_at'] as int);
        final en = DateTime.fromMillisecondsSinceEpoch(e['end_at'] as int);
        final cs = s.isBefore(dayStart) ? dayStart : s;
        final ce = en.isAfter(dayEnd) ? dayEnd : en;
        if (!ce.isAfter(cs)) continue;
        out.add(DaySlot(
          start: cs,
          end: ce,
          title: dbStr(e['title'], 'Event'),
          kind: DaySlotKind.event,
          entityId: dbStr(e['id']),
          reason: 'Calendar',
          locked: true,
          priority: 200,
        ));
      }
    } catch (_) {}

    final blocks = await _plan.listBlocksOnDay(d);
    for (final b in blocks) {
      final s = DateTime.fromMillisecondsSinceEpoch(b['start_at'] as int);
      final en = DateTime.fromMillisecondsSinceEpoch(b['end_at'] as int);
      final cs = s.isBefore(dayStart) ? dayStart : s;
      final ce = en.isAfter(dayEnd) ? dayEnd : en;
      if (!ce.isAfter(cs)) continue;
      out.add(DaySlot(
        start: cs,
        end: ce,
        title: dbStr(b['title'], 'Block'),
        kind: DaySlotKind.block,
        entityId: dbStrOrNull(b['task_id']) ?? dbStr(b['id']),
        reason: 'Time block',
        locked: true,
        priority: 180,
      ));
    }

    final scheduled = await _tasks.listScheduledOnDay(d);
    for (final t in scheduled) {
      if (t.scheduledStart == null) continue;
      final s = DateTime.fromMillisecondsSinceEpoch(t.scheduledStart!);
      final en = t.scheduledEnd != null
          ? DateTime.fromMillisecondsSinceEpoch(t.scheduledEnd!)
          : s.add(Duration(minutes: t.estimatedMinutes ?? 30));
      if (out.any((x) => x.entityId == t.id)) continue;
      final cs = s.isBefore(dayStart) ? dayStart : s;
      final ce = en.isAfter(dayEnd) ? dayEnd : en;
      if (!ce.isAfter(cs)) continue;
      out.add(DaySlot(
        start: cs,
        end: ce,
        title: t.title,
        kind: DaySlotKind.task,
        entityId: t.id,
        reason: 'Already scheduled',
        locked: true,
        priority: 160,
      ));
    }

    return out;
  }

  Future<List<FlexibleCandidate>> _collectFlexible(
    DateTime d,
    List<DaySlot> locked,
    int maxFlexible,
  ) async {
    final lockedIds = locked.map((s) => s.entityId).whereType<String>().toSet();
    final blockedIds = await _tasks.listBlockedTaskIds();
    final candidates = <FlexibleCandidate>[];

    final overdue = await _tasks.listOverdue();
    final dueToday = await _tasks.listDueToday();
    final open = await _tasks.listOpen();

    void addTask(Task t, int base, String reason) {
      if (lockedIds.contains(t.id)) return;
      if (blockedIds.contains(t.id)) return;
      if (candidates.any((c) => c.id == t.id)) return;
      if (t.scheduledStart != null) return;
      final dur = (t.estimatedMinutes ?? _defaultTaskMinutes(t)).clamp(15, 180);
      var score = base + t.priority * 6;
      if (t.projectId != null) score += 8;
      if (t.goalId != null) score += 5;
      candidates.add(FlexibleCandidate(
        id: t.id,
        title: t.title,
        kind: DaySlotKind.task,
        durationMin: dur,
        score: score,
        reason: reason,
      ));
    }

    for (final t in overdue) {
      addTask(t, 100, 'Overdue');
    }
    for (final t in dueToday) {
      addTask(t, 85, 'Due today');
    }
    for (final t in open) {
      if (t.isOverdue || t.isDueToday) continue;
      addTask(t, 40 + t.priority * 3, t.projectId != null ? 'Project work' : 'Open task');
    }

    final habits = await _habits.listActive();
    final dayKeyMs = HabitRepository.dayKey(d);
    final db = await _db.database;
    for (final h in habits) {
      if (lockedIds.contains(h.id)) continue;
      try {
        final occ = await db.query(
          'habit_occurrences',
          where: 'habit_id = ? AND scheduled_date = ?',
          whereArgs: [h.id, dayKeyMs],
          limit: 1,
        );
        if (occ.isNotEmpty && dbStr(occ.first['status']) == 'COMPLETED') continue;
      } catch (_) {}
      candidates.add(FlexibleCandidate(
        id: h.id,
        title: h.title,
        kind: DaySlotKind.habit,
        durationMin: 15,
        score: 55,
        reason: 'Habit',
      ));
    }

    final routines = await _routines.listActive();
    for (final r in routines) {
      if (lockedIds.contains(r.id)) continue;
      final steps = await _routines.listSteps(r.id);
      var mins = 0;
      for (final s in steps) {
        mins += (s['estimated_minutes'] as int?) ?? 10;
      }
      if (mins <= 0) mins = r.estimatedMinutes ?? 25;
      mins = mins.clamp(15, 90);

      var score = 60;
      final name = r.name.toLowerCase();
      if (name.contains('morning')) score = 75;
      if (name.contains('evening') || name.contains('night')) score = 35;

      candidates.add(FlexibleCandidate(
        id: r.id,
        title: r.name,
        kind: DaySlotKind.routine,
        durationMin: mins,
        score: score,
        reason: 'Routine',
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(maxFlexible).toList();
  }

  int _defaultTaskMinutes(Task t) {
    if (t.priority >= 3) return 45;
    if (t.projectId != null) return 40;
    return 30;
  }

  bool _overlapsAny(List<DaySlot> slots, DateTime s, DateTime e) {
    for (final x in slots) {
      if (s.isBefore(x.end) && e.isAfter(x.start)) return true;
    }
    return false;
  }

  List<(DateTime, DateTime)> _freeGaps(
    DateTime from,
    DateTime to,
    List<DaySlot> locked,
  ) {
    final sorted = [...locked]..sort((a, b) => a.start.compareTo(b.start));
    final gaps = <(DateTime, DateTime)>[];
    var cursor = from;
    for (final s in sorted) {
      if (s.start.isAfter(cursor)) {
        gaps.add((cursor, s.start.isAfter(to) ? to : s.start));
      }
      if (s.end.isAfter(cursor)) cursor = s.end;
      if (cursor.isAfter(to)) break;
    }
    if (cursor.isBefore(to)) gaps.add((cursor, to));
    return gaps.where((g) => g.$2.difference(g.$1).inMinutes >= 10).toList();
  }

  (DateTime, DateTime)? _placeInGaps(List<(DateTime, DateTime)> gaps, int minutes) {
    for (var i = 0; i < gaps.length; i++) {
      final g = gaps[i];
      final avail = g.$2.difference(g.$1).inMinutes;
      if (avail >= minutes) {
        final start = g.$1;
        final end = start.add(Duration(minutes: minutes));
        return (start, end);
      }
    }
    if (minutes > 15) {
      var bestI = -1;
      var bestAvail = 0;
      for (var i = 0; i < gaps.length; i++) {
        final avail = gaps[i].$2.difference(gaps[i].$1).inMinutes;
        if (avail >= 15 && avail > bestAvail) {
          bestAvail = avail;
          bestI = i;
        }
      }
      if (bestI >= 0) {
        final g = gaps[bestI];
        final use = bestAvail.clamp(15, minutes);
        return (g.$1, g.$1.add(Duration(minutes: use)));
      }
    }
    return null;
  }

  void _consumeGap(List<(DateTime, DateTime)> gaps, DateTime start, DateTime end) {
    for (var i = 0; i < gaps.length; i++) {
      final g = gaps[i];
      if (!start.isBefore(g.$2) || !end.isAfter(g.$1)) continue;
      final before = start.isAfter(g.$1) ? (g.$1, start) : null;
      final after = end.isBefore(g.$2) ? (end, g.$2) : null;
      gaps.removeAt(i);
      if (after != null && after.$2.difference(after.$1).inMinutes >= 10) {
        gaps.insert(i, after);
      }
      if (before != null && before.$2.difference(before.$1).inMinutes >= 10) {
        gaps.insert(i, before);
      }
      return;
    }
  }
}
