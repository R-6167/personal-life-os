import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/export_service.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import 'day_planner.dart';

/// Local PersonalContext + patterns from activity history.
class IntelligenceAssistant {
  IntelligenceAssistant({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

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
    final ctx = await buildContext();
    final q = userMessage.trim().toLowerCase();

    if (q.contains('pattern') || q.contains('history') || q.contains('lately')) {
      return ctx.patternSummary();
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
      return ctx.focusAdvice();
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
    if (q.contains('bill') || q.contains('pay')) {
      if (ctx.openBillCount == 0) return 'No open bill occurrences.';
      return 'Open bills:\n• ${ctx.billTitles.join('\n• ')}\nPay from Today or Finance — you enter the amount.';
    }
    if (q.contains('project')) {
      if (ctx.projectCount == 0) return 'No active projects. Create one under a goal in Life.';
      return 'Active projects:\n• ${ctx.projectTitles.join('\n• ')}\nOpen a project for milestones and tasks.';
    }
    if (q.contains('spend') ||
        q.contains('money') ||
        q.contains('expense') ||
        q.contains('finance')) {
      final major = (ctx.monthSpendMinor / 100).toStringAsFixed(2);
      return "This month's recorded spend: ${Defaults.currency} $major (local expenses only).\nBills open: ${ctx.openBillCount}.";
    }
    if (q.contains('task') || q.contains('todo') || q.contains('work')) {
      if (ctx.openTaskCount == 0) return 'No open tasks. Capture when something appears.';
      return 'Open tasks (${ctx.openTaskCount}):\n• ${ctx.topTaskTitles.join('\n• ')}';
    }
    if (q.contains('help') || q.contains('what can')) {
      return 'Offline assistant on your SQLite data.\n'
          'Try: plan · focus · overdue · habits · bills · patterns · spend\n'
          'I suggest next actions from Personal Context + ranked day plan.';
    }
    return ctx.focusAdvice();
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
      steps.add('Next task: ${topTaskTitles.isNotEmpty ? topTaskTitles.first : 'review open work'}');
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
      buf.writeln('Ask "patterns" for recent activity signals.');
    }
    buf.writeln('(Offline · from your data only)');
    return buf.toString();
  }
}
