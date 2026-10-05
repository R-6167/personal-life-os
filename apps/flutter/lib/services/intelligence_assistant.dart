import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/export_service.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import 'day_planner.dart';
import 'life_memory.dart';
import 'life_thread.dart';
import 'needs_attention.dart';
import 'personal_context_engine.dart';

/// Local PersonalContext + patterns from activity history.
class IntelligenceAssistant {
  IntelligenceAssistant({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;
  final List<String> _sessionUser = [];
  final List<String> _sessionAssistant = [];

  LifeMemoryService get memory => LifeMemoryService(db: _db);

  void clearSession() {
    _sessionUser.clear();
    _sessionAssistant.clear();
  }

  Future<PersonalContext> buildContext() async {
    final tasks = TaskRepository(_db);
    final habits = HabitRepository(_db);
    final bills = BillRepository(_db);
    final expenses = ExpenseRepository(_db);
    final projects = ProjectRepository(_db);

    final open = await tasks.listOpen();
    final overdue = await tasks.listOverdue();
    final dueToday = await tasks.listDueToday();
    final activeHabits = await habits.listActive();
    final billOcc = await bills.listOpenOccurrences();
    final spend = await expenses.totalMinorThisMonth();
    final activeProjects = await projects.listActive();
    final activity = await ExportService(_db).recentActivity(limit: 80);

    final eventCounts = <String, int>{};
    for (final a in activity) {
      final t = '${a['event_type']}';
      eventCounts[t] = (eventCounts[t] ?? 0) + 1;
    }

    return PersonalContext(
      now: DateTime.now(),
      openTaskCount: open.length,
      overdueCount: overdue.length,
      dueTodayCount: dueToday.length,
      habitCount: activeHabits.length,
      openBillCount: billOcc.length,
      projectCount: activeProjects.length,
      monthSpendMinor: spend,
      topOverdueTitles: overdue.take(3).map((t) => t.title).toList(),
      topTaskTitles: open.take(5).map((t) => t.title).toList(),
      habitTitles: activeHabits.take(5).map((h) => h.title).toList(),
      billTitles: billOcc.take(3).map((b) => b.billName ?? 'Bill').toList(),
      projectTitles: activeProjects.take(3).map((p) => p.title).toList(),
      recentEventTypes: eventCounts,
      activityCount: activity.length,
    );
  }

  Future<String> reply(String userMessage) async {
    final raw = userMessage.trim();
    final q = raw.toLowerCase();
    _sessionUser.add(raw);

    String answer;
    try {
      answer = await _route(q, raw);
    } catch (e) {
      answer = 'Something went wrong reading local data: $e';
    }

    _sessionAssistant.add(answer);
    while (_sessionUser.length > 12) {
      _sessionUser.removeAt(0);
      if (_sessionAssistant.isNotEmpty) _sessionAssistant.removeAt(0);
    }
    return answer;
  }

  Future<String> _route(String q, String raw) async {
    final ctx = await buildContext();

    if (q.contains('pattern') || q.contains('history') || q.contains('lately')) {
      return ctx.patternSummary();
    }
    if (q.contains('insight') || q.contains('reflect') || q.contains('how am i')) {
      return _insightsReply();
    }
    if (q.contains('remember') ||
        q.contains('recall') ||
        q.contains('what do you know') ||
        q.contains('search memory') ||
        q.startsWith('about ') ||
        q.contains('what about')) {
      final subject = _extractSubject(raw, q);
      return _memoryReply(subject.isEmpty ? raw : subject);
    }
    if (q.contains('why') &&
        (q.contains('overdue') ||
            q.contains('behind') ||
            q.contains('busy') ||
            q.contains('stuck') ||
            q.contains('this'))) {
      return _whyReply(ctx);
    }
    if (q.contains('goal') &&
        (q.contains('progress') || q.contains('status') || q.contains('how'))) {
      return _goalProgressReply(raw);
    }
    if (q.contains('situation') ||
        q.contains('context') ||
        q.contains('capacity') ||
        q.contains('pressure') ||
        q.contains('full picture') ||
        q.contains('where am i')) {
      return _situationReply();
    }
    if (q.isEmpty ||
        q.contains('today') ||
        q.contains('brief') ||
        q.contains('summary') ||
        q.contains('focus') ||
        q.contains('afternoon') ||
        q.contains('morning') ||
        q.contains('should i') ||
        q.contains('what next')) {
      try {
        return await PersonalContextEngine(db: _db).build().then((s) => s.narrative());
      } catch (_) {
        return ctx.focusAdvice();
      }
    }
    if (q.contains('attention') || q.contains('urgent') || q.contains('needs')) {
      return _attentionReply();
    }
    if (q.contains('plan') ||
        q.contains('priority') ||
        q.contains('rank') ||
        q.contains('order') ||
        q.contains('do next') ||
        q.contains('do now')) {
      return DayPlanner(db: _db).planNarrative(limit: 6);
    }
    if (q.contains('overdue')) {
      if (ctx.overdueCount == 0) return 'Nothing overdue. Clear runway.';
      return 'Overdue (${ctx.overdueCount}):\n• ${ctx.topOverdueTitles.join('\n• ')}\nClear these before new work.';
    }
    if (q.contains('habit')) {
      if (ctx.habitCount == 0) return 'No active habits. Add one under Life.';
      return 'Habits (${ctx.habitCount}):\n• ${ctx.habitTitles.join('\n• ')}\nLog from Today when done (one log per day).';
    }
    if (q.contains('bill') || (q.contains('pay') && !q.contains('payment'))) {
      if (ctx.openBillCount == 0) return 'No open bill occurrences.';
      return 'Open bills:\n• ${ctx.billTitles.join('\n• ')}\nPay from Today or Finance — you enter the amount.';
    }
    if (q.contains('project')) {
      if (ctx.projectCount == 0) {
        return 'No active projects. Create one under a goal in Life.';
      }
      return 'Active projects:\n• ${ctx.projectTitles.join('\n• ')}\nOpen a project for milestones and tasks.';
    }
    if (q.contains('spend') ||
        q.contains('money') ||
        q.contains('expense') ||
        q.contains('finance') ||
        q.contains('cash')) {
      final major = (ctx.monthSpendMinor / 100).toStringAsFixed(2);
      return "This month's recorded spend: ${Defaults.currency} $major (local expenses only).\nBills open: ${ctx.openBillCount}.";
    }
    if (q.contains('task') || q.contains('todo') || q.contains('work')) {
      if (ctx.openTaskCount == 0) return 'No open tasks. Capture when something appears.';
      return 'Open tasks (${ctx.openTaskCount}):\n• ${ctx.topTaskTitles.join('\n• ')}';
    }
    if (q.contains('help') || q.contains('what can')) {
      return 'Offline assistant on your SQLite data.\n'
          'Try: focus · situation · plan · overdue · habits · bills · patterns · insights\n'
          'Memory: “remember X” or “what about Y”\n'
          'Reasoning: “why am I behind?” · “goal progress”\n'
          'No cloud — answers from notes, activity, tasks, and links only.';
    }

    final mem = await memory.recall(raw, limit: 6);
    if (mem.isNotEmpty) {
      return _formatMemory(mem, raw);
    }

    if (_sessionUser.length >= 2) {
      return 'I only reason over your local data. Try “focus”, “plan”, “insights”, '
          'or “remember ${raw.length > 40 ? '${raw.substring(0, 40)}…' : raw}”.';
    }

    return ctx.focusAdvice();
  }

  String _extractSubject(String raw, String q) {
    for (final prefix in [
      'remember ',
      'recall ',
      'what about ',
      'what do you know about ',
      'search memory ',
      'about ',
    ]) {
      if (q.startsWith(prefix)) {
        return raw.substring(prefix.length).trim();
      }
      final i = q.indexOf(prefix);
      if (i >= 0) {
        return raw.substring(i + prefix.length).trim();
      }
    }
    return raw.trim();
  }

  Future<String> _memoryReply(String subject) async {
    final facts = await memory.recall(subject, limit: 10);
    if (facts.isEmpty) {
      return 'Nothing in notes, tasks, or activity matched “$subject”.\n'
          'Write a note or link entities so memory can grow.';
    }
    final related = await memory.contextAround(subject, limit: 6);
    final buf = StringBuffer()
      ..writeln('Memory for “$subject” (local):')
      ..writeln();
    for (final f in facts.take(8)) {
      buf.writeln('• [${f.kind}] ${f.text}');
    }
    if (related.length > facts.length) {
      buf.writeln();
      buf.writeln('Related:');
      for (final line in related.skip(facts.length > 3 ? 3 : 0).take(4)) {
        buf.writeln(line.startsWith('  ') ? line : '• $line');
      }
    }
    buf.writeln();
    buf.writeln('(From notes, titles, activity & entity links)');
    return buf.toString();
  }

  String _formatMemory(List<MemoryFact> mem, String raw) {
    final buf = StringBuffer()
      ..writeln('Closest matches for “$raw”:')
      ..writeln();
    for (final f in mem) {
      buf.writeln('• [${f.kind}] ${f.text}');
    }
    return buf.toString();
  }

  Future<String> _insightsReply() async {
    final list = await memory.insights(limit: 8);
    if (list.isEmpty) {
      return 'Not enough history for insights yet. Use tasks, habits, and work sessions.';
    }
    final buf = StringBuffer()
      ..writeln('Reflections from your data:')
      ..writeln();
    for (var i = 0; i < list.length; i++) {
      buf.writeln('${i + 1}. ${list[i]}');
    }
    buf.writeln();
    buf.writeln('Ask “why am I behind?” or “plan” for next steps.');
    return buf.toString();
  }

  Future<String> _whyReply(PersonalContext ctx) async {
    final insights = await memory.insights(limit: 5);
    final buf = StringBuffer()..writeln('Possible reasons (from local signals):');
    var n = 1;
    if (ctx.overdueCount > 0) {
      buf.writeln(
        '$n. ${ctx.overdueCount} overdue item${ctx.overdueCount == 1 ? '' : 's'} '
        '(${ctx.topOverdueTitles.take(2).join('; ')}) — they steal focus.',
      );
      n++;
    }
    if (ctx.openTaskCount > 12) {
      buf.writeln(
          '$n. Large open backlog (${ctx.openTaskCount} tasks) — prioritise ruthlessly.');
      n++;
    }
    if (ctx.openBillCount > 0) {
      buf.writeln(
          '$n. Open bills may be mental load (${ctx.billTitles.take(2).join('; ')}).');
      n++;
    }
    for (final line in insights) {
      if (line.contains('faster than finishing') ||
          line.contains('quiet for') ||
          line.contains('No completed work')) {
        buf.writeln('$n. $line');
        n++;
      }
    }
    if (n == 1) {
      buf.writeln(
          'No strong red flags in the data. Protect focus blocks and finish one milestone.');
    } else {
      buf.writeln();
      buf.writeln('Try: clear 1–2 overdue, then “plan” for a ranked short list.');
    }
    return buf.toString();
  }

  Future<String> _goalProgressReply(String raw) async {
    final db = await _db.database;
    final goals = await db.query(
      'goals',
      where: "status = 'ACTIVE' OR status IS NULL OR status = 'IN_PROGRESS'",
      orderBy: 'updated_at DESC',
      limit: 5,
    );
    if (goals.isEmpty) {
      return 'No active goals. Create one under Life to track progress.';
    }
    final q = raw.toLowerCase();
    Map<String, Object?>? pick;
    for (final g in goals) {
      final title = '${g['title']}'.toLowerCase();
      if (title.isNotEmpty && q.contains(title)) {
        pick = g;
        break;
      }
    }
    pick ??= goals.first;

    final id = '${pick['id']}';
    final thread = await LifeThreadService(_db).forGoal(id);
    final buf = StringBuffer()
      ..writeln('Goal: ${pick['title']}')
      ..writeln(thread.doingSummary)
      ..writeln()
      ..writeln(
        'Progress ${(thread.progressRatio * 100).round()}% · '
        '${thread.tasksDone}/${thread.tasksTotal} tasks · '
        '${thread.milestonesDone}/${thread.milestonesTotal} milestones',
      );
    if (thread.nextMoves.isNotEmpty) {
      buf.writeln();
      buf.writeln('Next moves:');
      for (final m in thread.nextMoves.take(4)) {
        buf.writeln('• ${m.title} (${m.reason})');
      }
    }
    return buf.toString();
  }

  Future<String> _situationReply() async {
    final s = await PersonalContextEngine(db: _db).build();
    return s.narrative();
  }

  Future<String> _attentionReply() async {
    try {
      final items = await NeedsAttentionService(db: _db).build(limit: 12);
      if (items.isEmpty) {
        return 'Needs Attention is clear. No urgent practical or finance items.';
      }
      final buf = StringBuffer()..writeln('Needs attention (${items.length}):');
      for (final i in items.take(8)) {
        final sub = i.subtitle.trim();
        buf.writeln(sub.isEmpty ? '• ${i.title}' : '• ${i.title} — $sub');
      }
      return buf.toString();
    } catch (_) {
      return 'Could not load Needs Attention right now.';
    }
  }
}

class PersonalContext {
  PersonalContext({
    required this.now,
    required this.openTaskCount,
    required this.overdueCount,
    required this.dueTodayCount,
    required this.habitCount,
    required this.openBillCount,
    required this.projectCount,
    required this.monthSpendMinor,
    required this.topOverdueTitles,
    required this.topTaskTitles,
    required this.habitTitles,
    required this.billTitles,
    required this.projectTitles,
    required this.recentEventTypes,
    required this.activityCount,
  });

  final DateTime now;
  final int openTaskCount;
  final int overdueCount;
  final int dueTodayCount;
  final int habitCount;
  final int openBillCount;
  final int projectCount;
  final int monthSpendMinor;
  final List<String> topOverdueTitles;
  final List<String> topTaskTitles;
  final List<String> habitTitles;
  final List<String> billTitles;
  final List<String> projectTitles;
  final Map<String, int> recentEventTypes;
  final int activityCount;

  String briefing() => focusAdvice();

  String patternSummary() {
    if (activityCount == 0) {
      return 'Not enough history yet. Use the app — patterns appear from activity_events.';
    }
    final sorted = recentEventTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).map((e) => '• ${e.key}: ${e.value}').join('\n');
    return 'Recent activity patterns ($activityCount events sampled):\n$top\n'
        'Use this as a signal of where your energy goes.';
  }

  String focusAdvice() {
    final hour = now.hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final steps = <String>[];
    if (overdueCount > 0) {
      steps.add('Clear overdue first: ${topOverdueTitles.take(2).join('; ')}');
    }
    if (openBillCount > 0 && (hour >= 9 && hour <= 18)) {
      steps.add('Settle open bills if you can (${billTitles.take(2).join('; ')})');
    }
    if (dueTodayCount > 0 || topTaskTitles.isNotEmpty) {
      steps.add(
          'Next task: ${topTaskTitles.isNotEmpty ? topTaskTitles.first : 'review open work'}');
    }
    if (habitCount > 0 && hour < 21) {
      steps.add('Keep a habit alive: ${habitTitles.take(2).join('; ')}');
    }
    if (projectCount > 0 && steps.length < 3) {
      steps.add('Push a project: ${projectTitles.first}');
    }
    if (steps.isEmpty) {
      steps.add('Inbox is calm. Capture a goal or plan tomorrow with Calendar.');
    }

    final buf = StringBuffer()
      ..writeln('$greet. Suggested focus:')
      ..writeln()
      ..writeln(steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n'))
      ..writeln()
      ..writeln(
        'Context — tasks $openTaskCount · overdue $overdueCount · '
        'habits $habitCount · bills $openBillCount · projects $projectCount',
      )
      ..writeln(
        'Spend this month: ${Defaults.currency} ${(monthSpendMinor / 100).toStringAsFixed(2)}',
      );
    if (activityCount > 0) {
      buf.writeln('Ask "patterns" or "insights" for deeper signals.');
    }
    buf.writeln('(Offline · from your data only)');
    return buf.toString();
  }
}
