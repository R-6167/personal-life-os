import '../data/database.dart';
import '../data/task_repository.dart';
import '../data/habit_repository.dart';
import '../data/bill_repository.dart';
import '../data/expense_repository.dart';
import '../domain/enums.dart';

/// Local-first PersonalContext + rule-based assistant (doc §54).
/// No network. Answers from SQLite state only.
class IntelligenceAssistant {
  IntelligenceAssistant({
    AppDatabase? db,
  }) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<PersonalContext> buildContext() async {
    final tasks = TaskRepository(_db);
    final habits = HabitRepository(_db);
    final bills = BillRepository(_db);
    final expenses = ExpenseRepository(_db);

    final open = await tasks.listOpen();
    final overdue = await tasks.listOverdue();
    final dueToday = await tasks.listDueToday();
    final activeHabits = await habits.listActive();
    final billOcc = await bills.listOpenOccurrences();
    final spend = await expenses.totalMinorThisMonth();

    return PersonalContext(
      now: DateTime.now(),
      openTaskCount: open.length,
      overdueCount: overdue.length,
      dueTodayCount: dueToday.length,
      habitCount: activeHabits.length,
      openBillCount: billOcc.length,
      monthSpendMinor: spend,
      topOverdueTitles: overdue.take(3).map((t) => t.title).toList(),
      topTaskTitles: open.take(5).map((t) => t.title).toList(),
      habitTitles: activeHabits.take(5).map((h) => h.title).toList(),
      billTitles: billOcc.take(3).map((b) => b.billName ?? 'Bill').toList(),
    );
  }

  Future<String> reply(String userMessage) async {
    final ctx = await buildContext();
    final q = userMessage.trim().toLowerCase();

    if (q.isEmpty) {
      return ctx.briefing();
    }
    if (q.contains('today') || q.contains('brief') || q.contains('summary') || q.contains('focus')) {
      return ctx.briefing();
    }
    if (q.contains('overdue')) {
      if (ctx.overdueCount == 0) return 'Nothing overdue. Nice work.';
      return 'You have ${ctx.overdueCount} overdue task(s):\n• ${ctx.topOverdueTitles.join('\n• ')}';
    }
    if (q.contains('habit')) {
      if (ctx.habitCount == 0) return 'No active habits yet. Add one under Habits.';
      return 'Active habits (${ctx.habitCount}):\n• ${ctx.habitTitles.join('\n• ')}\nLog them from Today when done.';
    }
    if (q.contains('bill') || q.contains('pay')) {
      if (ctx.openBillCount == 0) return 'No open bill occurrences.';
      return 'Open bills (${ctx.openBillCount}):\n• ${ctx.billTitles.join('\n• ')}\nPay from Today — that records an expense (bill ≠ expense).';
    }
    if (q.contains('spend') || q.contains('money') || q.contains('expense') || q.contains('finance')) {
      final major = (ctx.monthSpendMinor / 100).toStringAsFixed(2);
      return 'This month\'s recorded spend: ${Defaults.currency} $major (from local expenses only).';
    }
    if (q.contains('task') || q.contains('todo') || q.contains('work')) {
      if (ctx.openTaskCount == 0) return 'No open tasks. Capture one when something appears.';
      return 'Open tasks (${ctx.openTaskCount}):\n• ${ctx.topTaskTitles.join('\n• ')}';
    }
    if (q.contains('help') || q.contains('what can')) {
      return 'I run fully offline on your SQLite data.\n'\n          'Ask about: today, overdue, tasks, habits, bills, spend.\n'\n          'I don\'t call the cloud — answers come from Personal Context.';
    }
    return ctx.briefing();
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
    required this.monthSpendMinor,
    required this.topOverdueTitles,
    required this.topTaskTitles,
    required this.habitTitles,
    required this.billTitles,
  });

  final DateTime now;
  final int openTaskCount;
  final int overdueCount;
  final int dueTodayCount;
  final int habitCount;
  final int openBillCount;
  final int monthSpendMinor;
  final List<String> topOverdueTitles;
  final List<String> topTaskTitles;
  final List<String> habitTitles;
  final List<String> billTitles;

  String briefing() {
    final hour = now.hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final buf = StringBuffer()
      ..writeln('$greet. Here is your local context:')
      ..writeln('• Open tasks: $openTaskCount (due/overdue focus: $dueTodayCount)')
      ..writeln('• Overdue: $overdueCount')
      ..writeln('• Habits to keep: $habitCount')
      ..writeln('• Bills open: $openBillCount')
      ..writeln(
        '• Month spend: ${Defaults.currency} ${(monthSpendMinor / 100).toStringAsFixed(2)}',
      );
    if (overdueCount > 0) {
      buf.writeln('\nPriority — overdue:\n• ${topOverdueTitles.join('\n• ')}');
    } else if (topTaskTitles.isNotEmpty) {
      buf.writeln('\nSuggested focus:\n• ${topTaskTitles.take(3).join('\n• ')}');
    }
    buf.writeln('\n(All offline. No network used.)');
    return buf.toString();
  }
}
