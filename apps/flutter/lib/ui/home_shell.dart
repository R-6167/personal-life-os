import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/export_service.dart';
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
import 'more_panel.dart';
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
  final _export = ExportService(AppDatabase.instance);
  final _ext = ExtendedRepository(AppDatabase.instance);

  List<Task> _taskList = [];
  List<Task> _overdue = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];
  List<Project> _projectList = [];
  List<Expense> _expenseList = [];
  List<Bill> _billList = [];
  List<BillOccurrence> _billOcc = [];
  List<Routine> _routineList = [];
  List<Income> _incomeList = [];
  List<Map<String, Object?>> _eventsToday = [];
  int _monthSpendMinor = 0;

  final _input = TextEditingController();

  static const _titles = ['Today', 'Tasks', 'Habits', 'Goals', 'More'];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
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
    final bills = await _bills.listActive();
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
      _billList = bills;
      _billOcc = occ;
      _routineList = r;
      _incomeList = inc;
      _eventsToday = ev;
    });
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    switch (_tab) {
      case 1:
        await _tasks.create(title: text, dueAt: AppDatabase.endOfTodayMs());
        break;
      case 2:
        await _habits.create(title: text);
        break;
      case 3:
        await _goals.create(title: text);
        break;
    }
    _input.clear();
    await _reload();
  }

  Future<void> _shareBackup() async {
    final json = await _export.buildBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/personal-life-os-backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Personal Life OS backup');
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
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
                _tab == 0 ? _greeting : 'Offline · glass · local AI',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Intelligence',
              onPressed: _openAssistant,
              icon: const Icon(Icons.auto_awesome),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            if (_tab == 4)
              IconButton(onPressed: _shareBackup, icon: const Icon(Icons.ios_share)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAssistant,
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Text('Ask OS'),
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: GlassCard(
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      if (_tab >= 1 && _tab <= 3) _composer(),
                      Expanded(child: _body()),
                    ],
                  ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.check_box_outlined), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.repeat), label: 'Habits'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final hints = {1: 'New task (due today)…', 2: 'New habit…', 3: 'New goal…'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hints[_tab],
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          IconButton.filled(
            onPressed: _add,
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(backgroundColor: AppTheme.seed),
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _today();
      case 1:
        return _listTasks();
      case 2:
        return _listHabits();
      case 3:
        return _listGoals();
      case 4:
        return MorePanel(
          onChanged: _reload,
          projects: _projectList,
          routines: _routineList,
          bills: _billList,
          billOcc: _billOcc,
          notes: _noteList,
          expenses: _expenseList,
          income: _incomeList,
        );
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
              Text(_greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Your day', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Derived from local SQLite · ${Defaults.currency} $spend this month',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_overdue.isNotEmpty) ...[
          _section('Overdue', Colors.redAccent),
          ..._overdue.map((t) => _taskTile(t, highlight: true)),
        ],
        _section('Tasks', Colors.lightBlueAccent),
        if (_taskList.isEmpty)
          _hint('No open tasks')
        else
          ..._taskList.take(8).map(_taskTile),
        _section('Habits', Colors.greenAccent),
        if (_habitList.isEmpty)
          _hint('No habits yet')
        else
          ..._habitList.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(h.title, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.done_all, color: Colors.greenAccent),
                      onPressed: () async {
                        await _habits.markDoneToday(h.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged ${h.title}')));
                        }
                      },
                    ),
                  ),
                ),
              )),
        _section('Bills', Colors.orangeAccent),
        if (_billOcc.isEmpty)
          _hint('No open bills')
        else
          ..._billOcc.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(o.billName ?? 'Bill', style: const TextStyle(color: Colors.white)),
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
        _section('Calendar', Colors.cyanAccent),
        if (_eventsToday.isEmpty)
          _hint('No events today')
        else
          ..._eventsToday.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Text('${e['title']}', style: const TextStyle(color: Colors.white)),
                ),
              )),
        _section('Routines', Colors.purpleAccent),
        ..._routineList.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  title: Text(r.name, style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: Colors.purpleAccent),
                    onPressed: () async {
                      await _routines.completeToday(r.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Completed ${r.name}')));
                      }
                    },
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _section(String title, Color c) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      );

  Widget _hint(String m) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(m, style: TextStyle(color: Colors.white.withValues(alpha: 0.35))),
      );

  Widget _taskTile(Task t, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            title: Text(t.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              t.isOverdue ? 'OVERDUE' : t.status,
              style: TextStyle(
                color: t.isOverdue ? Colors.redAccent : Colors.white38,
                fontSize: 11,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent),
              onPressed: () async {
                await _tasks.complete(t.id);
                await _reload();
              },
            ),
          ),
        ),
      );

  Widget _listTasks() {
    if (_taskList.isEmpty) return Center(child: _hint('No open tasks'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: _taskList.map(_taskTile).toList(),
    );
  }

  Widget _listHabits() {
    if (_habitList.isEmpty) return Center(child: _hint('No habits'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: _habitList
          .map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(h.title, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.done_all, color: Colors.greenAccent),
                      onPressed: () async {
                        await _habits.markDoneToday(h.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged ${h.title}')));
                        }
                      },
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _listGoals() {
    if (_goalList.isEmpty) return Center(child: _hint('No goals'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: _goalList
          .map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(g.title, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.flag, color: Colors.amberAccent),
                      onPressed: () async {
                        await _goals.complete(g.id);
                        await _reload();
                      },
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
