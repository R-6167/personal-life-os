import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/export_service.dart';
import '../data/habit_repository.dart';
import '../data/planning_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/db_map.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'life_memory.dart';
import 'needs_attention.dart';

/// One pressure signal (overdue / approaching).
class PressureItem {
  PressureItem({
    required this.label,
    required this.kind,
    required this.score,
    this.entityId,
  });
  final String label;
  final String kind;
  final int score;
  final String? entityId;
}

/// Ranked next action opportunity.
class OpportunityItem {
  OpportunityItem({
    required this.title,
    required this.reason,
    required this.score,
    this.entityType,
    this.entityId,
    this.estimatedMinutes,
  });
  final String title;
  final String reason;
  final int score;
  final String? entityType;
  final String? entityId;
  final int? estimatedMinutes;
}

/// Full situational awareness of the user's life *right now*.
///
/// Layers:
///   CURRENT STATE · PRESSURE · CAPACITY · PRIORITY · CONTEXT · OPPORTUNITY
class PersonalSituation {
  PersonalSituation({
    required this.at,
    required this.currentStateLines,
    required this.pressure,
    required this.availableMinutesToday,
    required this.busyMinutesToday,
    required this.capacityLabel,
    required this.priorityLines,
    required this.contextLines,
    required this.opportunities,
    required this.openTaskCount,
    required this.overdueCount,
    required this.dueTodayCount,
    required this.habitCount,
    required this.openBillCount,
    required this.projectCount,
    required this.attentionCount,
    required this.monthSpendMinor,
  });

  final DateTime at;
  final List<String> currentStateLines;
  final List<PressureItem> pressure;
  final int availableMinutesToday;
  final int busyMinutesToday;
  final String capacityLabel;
  final List<String> priorityLines;
  final List<String> contextLines;
  final List<OpportunityItem> opportunities;

  final int openTaskCount;
  final int overdueCount;
  final int dueTodayCount;
  final int habitCount;
  final int openBillCount;
  final int projectCount;
  final int attentionCount;
  final int monthSpendMinor;

  String narrative() {
    final buf = StringBuffer();
    final hour = at.hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    buf.writeln('$greet — personal context');
    buf.writeln();
    buf.writeln('CURRENT STATE');
    buf.writeln('─────────────');
    for (final line in currentStateLines) {
      buf.writeln('• $line');
    }
    buf.writeln();
    buf.writeln('PRESSURE');
    buf.writeln('────────');
    if (pressure.isEmpty) {
      buf.writeln('• No critical pressure right now');
    } else {
      for (final p in pressure.take(6)) {
        buf.writeln('• ${p.label}');
      }
    }
    buf.writeln();
    buf.writeln('CAPACITY');
    buf.writeln('────────');
    buf.writeln(
      '• ~${availableMinutesToday ~/ 60}h ${availableMinutesToday % 60}m free today '
      '($busyMinutesToday m already committed)',
    );
    buf.writeln('• $capacityLabel');
    buf.writeln();
    buf.writeln('PRIORITY');
    buf.writeln('────────');
    for (final line in priorityLines.take(5)) {
      buf.writeln('• $line');
    }
    buf.writeln();
    buf.writeln('CONTEXT');
    buf.writeln('───────');
    if (contextLines.isEmpty) {
      buf.writeln('• Quiet history — not much recent activity');
    } else {
      for (final line in contextLines.take(5)) {
        buf.writeln('• $line');
      }
    }
    buf.writeln();
    buf.writeln('OPPORTUNITY');
    buf.writeln('───────────');
    if (opportunities.isEmpty) {
      buf.writeln('• Capture a task or review goals when ready');
    } else {
      for (final o in opportunities.take(5)) {
        final dur =
            o.estimatedMinutes != null ? ' (~${o.estimatedMinutes}m)' : '';
        buf.writeln('• ${o.title}$dur — ${o.reason}');
      }
    }
    buf.writeln();
    buf.writeln(
        '(Offline · synthesised from calendar, tasks, habits, finance, notes)');
    return buf.toString();
  }

  String brief() {
    final top =
        opportunities.isNotEmpty ? opportunities.first.title : 'nothing queued';
    return 'Free ~${availableMinutesToday ~/ 60}h · '
        'pressure ${pressure.length} · '
        'next: $top';
  }
}

/// Builds [PersonalSituation] from the whole offline OS.
class PersonalContextEngine {
  PersonalContextEngine({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<PersonalSituation> build({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final tasks = TaskRepository(_db);
    final habits = HabitRepository(_db);
    final bills = BillRepository(_db);
    final expenses = ExpenseRepository(_db);
    final projects = ProjectRepository(_db);
    final planning = PlanningRepository(_db);

    final open = await tasks.listOpen();
    final overdue = await tasks.listOverdue();
    final dueToday = await tasks.listDueToday();
    final activeHabits = await habits.listActive();
    final billOcc = await bills.listOpenOccurrences();
    final spend = await expenses.totalMinorThisMonth();
    final activeProjects = await projects.listActive();

    final free = await planning.availableMinutes(day: now);
    final dayStart = DateTime(now.year, now.month, now.day, 8);
    final dayEnd = DateTime(now.year, now.month, now.day, 22);
    final window = dayEnd.difference(dayStart).inMinutes;
    final busy = (window - free).clamp(0, window);

    List<AttentionItem> attention = [];
    try {
      attention = await NeedsAttentionService(db: _db).build(limit: 30);
    } catch (_) {}

    final state = <String>[];
    state.add(_clockLine(now));
    state.add(
      '${open.length} open task${open.length == 1 ? '' : 's'} · '
      '${dueToday.length} due today · ${overdue.length} overdue',
    );
    if (activeProjects.isNotEmpty) {
      state.add(
        '${activeProjects.length} active project${activeProjects.length == 1 ? '' : 's'}: '
        '${activeProjects.take(2).map((p) => p.title).join(', ')}',
      );
    }
    if (activeHabits.isNotEmpty) {
      state.add(
          '${activeHabits.length} active habit${activeHabits.length == 1 ? '' : 's'}');
    }
    if (billOcc.isNotEmpty) {
      state.add(
          '${billOcc.length} open bill occurrence${billOcc.length == 1 ? '' : 's'}');
    }
    if (attention.isNotEmpty) {
      state.add(
          '${attention.length} item${attention.length == 1 ? '' : 's'} need attention');
    }

    final pressure = <PressureItem>[];
    for (final t in overdue) {
      pressure.add(PressureItem(
        label: 'Overdue: ${t.title}',
        kind: 'OVERDUE_TASK',
        score: 100 + t.priority * 10,
        entityId: t.id,
      ));
    }
    for (final t in dueToday) {
      if (t.isOverdue) continue;
      pressure.add(PressureItem(
        label: 'Due today: ${t.title}',
        kind: 'DUE_TODAY',
        score: 70 + t.priority * 8,
        entityId: t.id,
      ));
    }
    for (final a in attention) {
      if (a.kind == AttentionKind.overdueTask || a.kind == AttentionKind.dueTask) {
        continue;
      }
      final boost = switch (a.severity) {
        AttentionSeverity.critical => 90,
        AttentionSeverity.high => 70,
        AttentionSeverity.medium => 40,
      };
      pressure.add(PressureItem(
        label: a.subtitle.isEmpty ? a.title : '${a.title} — ${a.subtitle}',
        kind: a.kind.name,
        score: boost + a.urgency,
        entityId: a.id,
      ));
    }
    for (final o in billOcc.take(5)) {
      final name = o.billName ?? 'Bill';
      final due = DateTime.fromMillisecondsSinceEpoch(o.dueAt);
      final late = due.isBefore(now);
      pressure.add(PressureItem(
        label: late ? 'Bill overdue: $name' : 'Bill due: $name',
        kind: late ? 'BILL_OVERDUE' : 'BILL_DUE',
        score: late ? 85 : 55,
        entityId: o.id,
      ));
    }
    pressure.sort((a, b) => b.score.compareTo(a.score));
    final seenP = <String>{};
    final pressureUnique = <PressureItem>[];
    for (final p in pressure) {
      if (seenP.add(p.label)) pressureUnique.add(p);
    }

    final capacityLabel =
        _capacityLabel(free, busy, window, pressureUnique.length);

    final priorityLines = <String>[];
    if (pressureUnique.isNotEmpty) {
      priorityLines.add('Relieve pressure: ${pressureUnique.first.label}');
    }
    final ranked = _rankOpenTasks(open, overdue, dueToday);
    for (final t in ranked.take(3)) {
      priorityLines.add('Task: ${t.title}${t.dueAt != null ? ' (due)' : ''}');
    }
    if (activeProjects.isNotEmpty && priorityLines.length < 4) {
      priorityLines.add('Project momentum: ${activeProjects.first.title}');
    }
    if (priorityLines.isEmpty) {
      priorityLines.add('No urgent work — good time to plan or capture');
    }

    final contextLines = <String>[];
    try {
      final activity = await ExportService(_db).recentActivity(limit: 40);
      final counts = <String, int>{};
      for (final a in activity) {
        final t = '${a['event_type']}';
        if (t.startsWith('APP_') || t == 'SMART_REMINDERS_SCHEDULED') continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted.take(4)) {
        contextLines.add(
          'Recent: ${e.key.replaceAll('_', ' ').toLowerCase()} ×${e.value}',
        );
      }
      for (final a in activity.take(8)) {
        final t = '${a['event_type']}';
        if (t.startsWith('APP_')) continue;
        contextLines.add('Last: ${t.replaceAll('_', ' ').toLowerCase()}');
        if (contextLines.length >= 6) break;
      }
    } catch (_) {}
    try {
      final insights = await LifeMemoryService(db: _db).insights(limit: 3);
      for (final i in insights) {
        contextLines.add(i);
      }
    } catch (_) {}

    final opportunities = <OpportunityItem>[];
    for (final t in [...overdue, ...dueToday]) {
      final est = t.estimatedMinutes ?? 30;
      if (est > free && free < 25) continue;
      opportunities.add(OpportunityItem(
        title: t.title,
        reason: t.isOverdue ? 'Overdue — clear pressure' : 'Due today',
        score: t.isOverdue ? 100 + t.priority : 80 + t.priority,
        entityType: 'TASK',
        entityId: t.id,
        estimatedMinutes: est,
      ));
    }
    for (final t in ranked) {
      if (opportunities.any((o) => o.entityId == t.id)) continue;
      final est = t.estimatedMinutes ?? 30;
      if (est > free + 15 && free < 45) {
        if (est > 20) continue;
      }
      opportunities.add(OpportunityItem(
        title: t.title,
        reason: _taskReason(t, free),
        score: 40 + t.priority * 10 + (t.dueAt != null ? 15 : 0),
        entityType: 'TASK',
        entityId: t.id,
        estimatedMinutes: est,
      ));
    }
    if (free >= 10 || opportunities.length < 3) {
      for (final h in activeHabits.take(3)) {
        opportunities.add(OpportunityItem(
          title: h.title,
          reason: 'Habit — small consistency win',
          score: 35,
          entityType: 'HABIT',
          entityId: h.id,
          estimatedMinutes: 15,
        ));
      }
    }
    for (final a in attention.take(5)) {
      if (a.kind == AttentionKind.overdueTask || a.kind == AttentionKind.dueTask) {
        continue;
      }
      opportunities.add(OpportunityItem(
        title: a.title,
        reason: a.subtitle.isEmpty ? 'Needs attention' : a.subtitle,
        score: 50 + a.urgency,
        entityType: a.kind.name,
        entityId: a.id,
      ));
    }
    opportunities.sort((a, b) => b.score.compareTo(a.score));
    final seenO = <String>{};
    final oppUnique = <OpportunityItem>[];
    for (final o in opportunities) {
      final key = o.entityId ?? o.title;
      if (seenO.add(key)) oppUnique.add(o);
    }

    return PersonalSituation(
      at: now,
      currentStateLines: state,
      pressure: pressureUnique,
      availableMinutesToday: free,
      busyMinutesToday: busy,
      capacityLabel: capacityLabel,
      priorityLines: priorityLines,
      contextLines: _uniqueStrings(contextLines),
      opportunities: oppUnique,
      openTaskCount: open.length,
      overdueCount: overdue.length,
      dueTodayCount: dueToday.length,
      habitCount: activeHabits.length,
      openBillCount: billOcc.length,
      projectCount: activeProjects.length,
      attentionCount: attention.length,
      monthSpendMinor: spend,
    );
  }

  String _clockLine(DateTime now) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final wd = weekdays[now.weekday - 1];
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$wd $h:$m';
  }

  String _capacityLabel(int free, int busy, int window, int pressureCount) {
    final ratio = window == 0 ? 0.0 : free / window;
    if (pressureCount >= 5 && free < 60) {
      return 'Tight capacity under pressure — protect a short focus block';
    }
    if (ratio >= 0.55) return 'Open runway — good day to advance a project';
    if (ratio >= 0.30) return 'Moderate free time — pick one meaningful block';
    if (free < 30) return 'Little free time left — micro-tasks or habits only';
    return 'Day is filling up — stay selective';
  }

  List<Task> _rankOpenTasks(
      List<Task> open, List<Task> overdue, List<Task> dueToday) {
    final dueIds = {...overdue.map((t) => t.id), ...dueToday.map((t) => t.id)};
    final rest = open.where((t) => !dueIds.contains(t.id)).toList();
    rest.sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      if (p != 0) return p;
      final da = a.dueAt ?? 1 << 62;
      final db = b.dueAt ?? 1 << 62;
      return da.compareTo(db);
    });
    return rest;
  }

  String _taskReason(Task t, int freeMin) {
    if (t.priority >= 3) return 'High priority';
    if (t.dueAt != null) return 'Has a deadline';
    final est = t.estimatedMinutes ?? 30;
    if (est <= freeMin) return 'Fits available time';
    return 'Open work';
  }

  List<String> _uniqueStrings(List<String> lines) {
    final seen = <String>{};
    final out = <String>[];
    for (final l in lines) {
      if (seen.add(l)) out.add(l);
    }
    return out;
  }
}
