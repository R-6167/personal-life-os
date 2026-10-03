import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/income_repository.dart';
import '../data/note_repository.dart';
import '../data/planning_repository.dart';
import '../data/project_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/day_planner.dart';
import '../services/error_log_service.dart';
import '../services/local_analytics.dart';
import '../services/notification_service.dart';
import '../services/query_cache.dart';
import '../utils/soft_future.dart';
import 'assistant_screen.dart';
import 'forms/create_forms.dart';
import 'hubs/finance_hub.dart';
import 'hubs/life_hub.dart';
import 'hubs/more_hub.dart';
import 'screens/planning_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/task_detail_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/glass.dart';
import 'widgets/offline_badge.dart';
import 'widgets/pay_bill_dialog.dart';
import 'widgets/section_header.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _ready = false;
  String? _error;
  bool _notifsSynced = false;

  final _tasks = TaskRepository(AppDatabase.instance);
  final _habits = HabitRepository(AppDatabase.instance);
  final _goals = GoalRepository(AppDatabase.instance);
  final _notes = NoteRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _expenses = ExpenseRepository(AppDatabase.instance);
  final _bills = BillRepository(AppDatabase.instance);
  final _routines = RoutineRepository(AppDatabase.instance);
  final _income = IncomeRepository(AppDatabase.instance);
  final _ext = ExtendedRepository(AppDatabase.instance);

  List<Task> _taskList = [];
  List<Task> _overdue = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];
  List<Project> _projectList = [];
  List<Expense> _expenseList = [];
  List<BillOccurrence> _billOcc = [];
  List<Routine> _routineList = [];
  List<Income> _incomeList = [];
  List<Map<String, Object?>> _eventsToday = [];
  List<PlanItem> _plan = [];
  List<Task> _scheduledToday = [];
  int _freeMinutes = 0;
  int _monthSpendMinor = 0;

  static const _titles = ['Today', 'Tasks', 'Life', 'Finance', 'More'];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await AppDatabase.instance.database;
      try {
        await NotificationService.instance.init();
      } catch (_) {}
      await _reload();
      setState(() => _ready = true);
      LocalAnalytics.instance.screenView('today');
    } catch (e, st) {
      await ErrorLogService.instance.log(message: 'boot: $e', stack: st.toString(), level: 'BOOT');
      setState(() {
        _error = e.toString();
        _ready = true;
      });
    }
  }

  Future<void> _reload() async {
    QueryCache.instance.invalidate();

    await softFuture(() async {
      await Future.wait([
        softFuture(() => _habits.ensureAllTodayOccurrences(), null, label: 'habit.ensure'),
        softFuture(() => _routines.ensureAllTodayOccurrences(), null, label: 'routine.ensure'),
      ]);
      await Future.wait([
        softFuture(() => _habits.markMissedBeforeToday(), 0, label: 'habit.missed'),
        softFuture(() => _routines.markMissedBeforeToday(), 0, label: 'routine.missed'),
      ]);
    }, null, label: 'maintenance');

    final taskList = await softFuture(_tasks.listOpen, <Task>[], label: 'tasks.open');
    final overdue = await softFuture(_tasks.listOverdue, <Task>[], label: 'tasks.overdue');
    final habitList = await softFuture(_habits.listActive, <Habit>[], label: 'habits');
    final goalList = await softFuture(_goals.listActive, <Goal>[], label: 'goals');
    final noteList = await softFuture(_notes.list, <Note>[], label: 'notes');
    final projectList = await softFuture(_projects.listActive, <Project>[], label: 'projects');
    final expenseList = await softFuture(_expenses.listRecent, <Expense>[], label: 'expenses');
    final monthSpend = await softFuture(_expenses.totalMinorThisMonth, 0, label: 'spend');
    final billOcc = await softFuture(_bills.listOpenOccurrences, <BillOccurrence>[], label: 'bills');
    final routineList = await softFuture(_routines.listActive, <Routine>[], label: 'routines');
    final incomeList = await softFuture(_income.listRecent, <Income>[], label: 'income');
    final eventsToday =
        await softFuture(_ext.listEventsToday, <Map<String, Object?>>[], label: 'events');
    final plan = await softFuture(() => DayPlanner().buildPlan(limit: 6), <PlanItem>[], label: 'plan');
    final scheduled =
        await softFuture(() => _tasks.listScheduledOnDay(DateTime.now()), <Task>[], label: 'scheduled');
    final freeMin = await softFuture(
      () => PlanningRepository(AppDatabase.instance).availableMinutes(day: DateTime.now()),
      0,
      label: 'freeMin',
    );

    if (!_notifsSynced) {
      await softFuture(() async {
        await NotificationService.instance.syncFromDatabase();
        _notifsSynced = true;
      }, null, label: 'notifs.sync');
    }

    if (!mounted) return;
    setState(() {
      _taskList = taskList;
      _overdue = overdue;
      _habitList = habitList;
      _goalList = goalList;
      _noteList = noteList;
      _projectList = projectList;
      _expenseList = expenseList;
      _monthSpendMinor = monthSpend;
      _billOcc = billOcc;
      _routineList = routineList;
      _incomeList = incomeList;
      _eventsToday = eventsToday;
      _plan = plan;
      _scheduledToday = scheduled;
      _freeMinutes = freeMin;
    });
  }

  Future<void> _openTask(Task t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
    );
    await _reload();
  }

  Future<void> _add() async {
    final ok = await showUniversalAdd(context);
    if (ok) {
      HapticFeedback.lightImpact();
      await _reload();
    }
  }

  void _onTab(int i) {
    setState(() => _tab = i);
    LocalAnalytics.instance.screenView(_titles[i].toLowerCase());
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[_tab], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(
                _tab == 0 ? _greeting : 'On-device · no account needed',
                style: TextStyle(fontSize: 11, color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
            ],
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(child: OfflineBadge()),
            ),
            IconButton(
              tooltip: 'Intelligence',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistantScreen()),
                );
              },
              icon: const Icon(Icons.auto_awesome),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: GlassCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _boot, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  )
                : _body(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _onTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.check_box_outlined), selectedIcon: Icon(Icons.check_box), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Life'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Finance'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _today();
      case 1:
        return _tasksView();
      case 2:
        return LifeHub(
          goals: _goalList,
          habits: _habitList,
          notes: _noteList,
          projects: _projectList,
          routines: _routineList,
          onChanged: _reload,
        );
      case 3:
        return FinanceHub(
          expenses: _expenseList,
          income: _incomeList,
          billOcc: _billOcc,
          monthSpendMinor: _monthSpendMinor,
          onChanged: _reload,
          onPayBill: (o) async {
            await promptAndPayBill(context, o);
            await _reload();
          },
        );
      case 4:
        return MoreHub(onChanged: _reload);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _today() {
    final spend = (_monthSpendMinor / 100).toStringAsFixed(2);
    return RefreshIndicator(
      color: AppTheme.amber,
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13)),
                const SizedBox(height: 4),
                const Text('What needs attention',
                    style: TextStyle(color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Pull to refresh · ~${_freeMinutes ~/ 60}h free · ${Defaults.currency} $spend spent',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          if (_scheduledToday.isNotEmpty) ...[
            SectionHeader(
              'On the clock',
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanningScreen()),
                  );
                },
                child: const Text('Plan'),
              ),
            ),
            ..._scheduledToday.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openTask(t),
                    child: ListTile(
                      dense: true,
                      title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        t.scheduledStart != null
                            ? TimeOfDay.fromDateTime(
                                    DateTime.fromMillisecondsSinceEpoch(t.scheduledStart!))
                                .format(context)
                            : 'Scheduled',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                      ),
                    ),
                  ),
                )),
          ],
          if (_plan.isNotEmpty) ...[
            const SectionHeader('Focus now'),
            ..._plan.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: InkWell(
                      onTap: p.kind == PlanItemKind.overdueTask ||
                              p.kind == PlanItemKind.dueTodayTask ||
                              p.kind == PlanItemKind.openTask
                          ? () async {
                              final match =
                                  [..._overdue, ..._taskList].where((x) => x.id == p.id);
                              if (match.isNotEmpty) await _openTask(match.first);
                            }
                          : null,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.amber.withValues(alpha: 0.2),
                            child: Text(
                              '${_plan.indexOf(p) + 1}',
                              style: const TextStyle(
                                  color: AppTheme.amber, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    style: const TextStyle(
                                        color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                Text(p.reason,
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
          if (_overdue.isNotEmpty) ...[
            const SectionHeader('Overdue'),
            ..._overdue.map((t) => _taskTile(t)),
          ],
          const SectionHeader('Tasks'),
          if (_taskList.isEmpty)
            _hint('Nothing open — use Add when something appears.')
          else
            ..._taskList.take(8).map(_taskTile),
          const SectionHeader('Habits'),
          if (_habitList.isEmpty)
            _hint('No habits yet.')
          else
            ..._habitList.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text(h.title, style: const TextStyle(color: AppTheme.silver)),
                      trailing: IconButton(
                        icon: const Icon(Icons.done_all, color: AppTheme.amber),
                        onPressed: () async {
                          await _habits.markDoneToday(h.id);
                          HapticFeedback.selectionClick();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged ${h.title}')),
                            );
                          }
                          await _reload();
                        },
                      ),
                    ),
                  ),
                )),
          const SectionHeader('Bills'),
          if (_billOcc.isEmpty)
            _hint('No open bills.')
          else
            ..._billOcc.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text(o.billName ?? 'Bill', style: const TextStyle(color: AppTheme.silver)),
                      trailing: FilledButton(
                        onPressed: () async {
                          final paid = await promptAndPayBill(context, o);
                          if (paid) {
                            HapticFeedback.mediumImpact();
                            await _reload();
                          }
                        },
                        child: const Text('Pay'),
                      ),
                    ),
                  ),
                )),
          if (_eventsToday.isNotEmpty) ...[
            const SectionHeader('Events'),
            ..._eventsToday.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Text('${e['title']}', style: const TextStyle(color: AppTheme.silver)),
                  ),
                )),
          ],
          if (_routineList.isNotEmpty) ...[
            const SectionHeader('Routines'),
            ..._routineList.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text(r.name, style: const TextStyle(color: AppTheme.silver)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_outline, color: AppTheme.amber),
                        onPressed: () async {
                          await _routines.completeToday(r.id);
                          HapticFeedback.selectionClick();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Completed ${r.name}')),
                            );
                          }
                          await _reload();
                        },
                      ),
                    ),
                  ),
                )),
          ],
          if (_projectList.isNotEmpty) ...[
            const SectionHeader('Active projects'),
            ..._projectList.take(4).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => ProjectDetailScreen(projectId: p.id)))
                          .then((_) => _reload());
                    },
                    child: Text(p.title, style: const TextStyle(color: AppTheme.silver)),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _tasksView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '${_taskList.length} open · tap to manage',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final ok = await showCreateForm(context, AddKind.task);
                  if (ok) await _reload();
                },
                child: const Text('New task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _taskList.isEmpty
              ? Center(child: _hint('No open tasks'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: _taskList.map(_taskTile).toList(),
                ),
        ),
      ],
    );
  }

  Widget _hint(String m) => Text(m, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)));

  Widget _taskTile(Task t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          onTap: () => _openTask(t),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
            subtitle: Text(
              t.isOverdue ? 'OVERDUE' : (t.isDueToday ? 'Due today' : t.status),
              style: TextStyle(
                color: t.isOverdue ? Colors.redAccent : AppTheme.silver.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
              onPressed: () async {
                await _tasks.complete(t.id);
                await _reload();
              },
            ),
          ),
        ),
      );
}
