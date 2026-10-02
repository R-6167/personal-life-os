import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/income_repository.dart';
import '../data/note_repository.dart';
import '../data/project_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'assistant_screen.dart';
import 'forms/create_forms.dart';
import 'hubs/finance_hub.dart';
import 'hubs/life_hub.dart';
import 'hubs/more_hub.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _ready = false;
  String? _error;

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
      await _reload();
      setState(() => _ready = true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _ready = true;
      });
    }
  }

  Future<void> _reload() async {
    final t = await _tasks.listOpen();
    final o = await _tasks.listOverdue();
    final h = await _habits.listActive();
    final g = await _goals.listActive();
    final n = await _notes.list();
    final p = await _projects.listActive();
    final e = await _expenses.listRecent();
    final spend = await _expenses.totalMinorThisMonth();
    final occ = await _bills.listOpenOccurrences();
    final r = await _routines.listActive();
    final inc = await _income.listRecent();
    final ev = await _ext.listEventsToday();
    setState(() {
      _taskList = t;
      _overdue = o;
      _habitList = h;
      _goalList = g;
      _noteList = n;
      _projectList = p;
      _expenseList = e;
      _monthSpendMinor = spend;
      _billOcc = occ;
      _routineList = r;
      _incomeList = inc;
      _eventsToday = ev;
    });
  }

  Future<void> _add() async {
    final ok = await showUniversalAdd(context);
    if (ok) await _reload();
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
                _tab == 0 ? _greeting : 'Offline · life workflows',
                style: TextStyle(fontSize: 11, color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
            ],
          ),
          actions: [
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
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  )
                : _body(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.check_box_outlined), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Life'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Finance'),
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
          onChanged: _reload,
        );
      case 3:
        return FinanceHub(
          expenses: _expenseList,
          income: _incomeList,
          billOcc: _billOcc,
          monthSpendMinor: _monthSpendMinor,
          onChanged: _reload,
        );
      case 4:
        return MoreHub(onChanged: _reload);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _today() {
    final spend = (_monthSpendMinor / 100).toStringAsFixed(2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13)),
              const SizedBox(height: 4),
              const Text('What needs attention', style: TextStyle(color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Derived from your data · ${Defaults.currency} $spend spent this month',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        if (_overdue.isNotEmpty) ...[
          _section('Overdue'),
          ..._overdue.map((t) => _taskTile(t, highlight: true)),
        ],
        _section('Tasks'),
        if (_taskList.isEmpty)
          _hint('Nothing open — use Add when something appears.')
        else
          ..._taskList.take(6).map(_taskTile),
        _section('Habits'),
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged ${h.title}')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              )),
        _section('Bills'),
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
                        await _bills.payOccurrence(o);
                        await _reload();
                      },
                      child: const Text('Pay'),
                    ),
                  ),
                ),
              )),
        if (_eventsToday.isNotEmpty) ...[
          _section('Events'),
          ..._eventsToday.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Text('${e['title']}', style: const TextStyle(color: AppTheme.silver)),
                ),
              )),
        ],
        if (_routineList.isNotEmpty) ...[
          _section('Routines'),
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Completed ${r.name}')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              )),
        ],
        if (_projectList.isNotEmpty) ...[
          _section('Active projects'),
          ..._projectList.take(4).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Text(p.title, style: const TextStyle(color: AppTheme.silver)),
                ),
              )),
        ],
      ],
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
                '${_taskList.length} open',
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      );

  Widget _hint(String m) => Text(m, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)));

  Widget _taskTile(Task t, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
            subtitle: Text(
              t.isOverdue ? 'OVERDUE' : t.status,
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
