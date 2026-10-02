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
import 'more_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_tab], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Text('Offline · schema v5 · contract', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          if (_tab == 4) IconButton(onPressed: _shareBackup, icon: const Icon(Icons.ios_share)),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
              : Column(
                  children: [
                    if (_tab >= 1 && _tab <= 3) _composer(),
                    Expanded(child: _body()),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111827),
        indicatorColor: const Color(0xFF1d4ed8),
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
    );
  }

  Widget _composer() {
    final hints = {1: 'New task (due today)…', 2: 'New habit…', 3: 'New goal…'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hints[_tab],
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1f2937),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
      ]),
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
      padding: const EdgeInsets.all(16),
      children: [
        Text(_greeting, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 6),
        const Text('Today', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const Text('Derived view — not a table', style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 14),
        if (_overdue.isNotEmpty) ...[
          _section('Overdue', Colors.redAccent),
          ..._overdue.map((t) => _taskTile(t, highlight: true)),
        ],
        _section('Tasks', Colors.lightBlueAccent),
        if (_taskList.isEmpty)
          const Text('No open tasks', style: TextStyle(color: Colors.white38))
        else
          ..._taskList.take(8).map(_taskTile),
        _section('Habits', Colors.greenAccent),
        ..._habitList.map((h) => Card(
              color: const Color(0xFF1f2937),
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
            )),
        _section('Bills', Colors.orangeAccent),
        ..._billOcc.map((o) => Card(
              color: const Color(0xFF1f2937),
              child: ListTile(
                title: Text(o.billName ?? 'Bill', style: const TextStyle(color: Colors.white)),
                trailing: TextButton(
                  onPressed: () async {
                    await _bills.payOccurrence(o);
                    await _reload();
                  },
                  child: const Text('Pay'),
                ),
              ),
            )),
        _section('Calendar', Colors.cyanAccent),
        if (_eventsToday.isEmpty)
          const Text('No events today', style: TextStyle(color: Colors.white38))
        else
          ..._eventsToday.map((e) => ListTile(
                title: Text('${e['title']}', style: const TextStyle(color: Colors.white)),
              )),
        _section('Routines', Colors.purpleAccent),
        ..._routineList.map((r) => Card(
              color: const Color(0xFF1f2937),
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
            )),
        const SizedBox(height: 12),
        Text('Month spend: ${Defaults.currency} $spend', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _section(String title, Color c) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      );

  Widget _taskTile(Task t, {bool highlight = false}) => Card(
        color: highlight ? const Color(0xFF3f1d1d) : const Color(0xFF1f2937),
        child: ListTile(
          title: Text(t.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(t.isOverdue ? 'OVERDUE' : t.status,
              style: TextStyle(color: t.isOverdue ? Colors.redAccent : Colors.white38, fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent),
            onPressed: () async {
              await _tasks.complete(t.id);
              await _reload();
            },
          ),
        ),
      );

  Widget _listTasks() {
    if (_taskList.isEmpty) return _empty('No open tasks');
    return ListView.builder(itemCount: _taskList.length, itemBuilder: (_, i) => _taskTile(_taskList[i]));
  }

  Widget _listHabits() {
    if (_habitList.isEmpty) return _empty('No habits');
    return ListView.builder(
      itemCount: _habitList.length,
      itemBuilder: (_, i) {
        final h = _habitList[i];
        return ListTile(
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
        );
      },
    );
  }

  Widget _listGoals() {
    if (_goalList.isEmpty) return _empty('No goals');
    return ListView.builder(
      itemCount: _goalList.length,
      itemBuilder: (_, i) {
        final g = _goalList[i];
        return ListTile(
          title: Text(g.title, style: const TextStyle(color: Colors.white)),
          trailing: IconButton(
            icon: const Icon(Icons.flag, color: Colors.amberAccent),
            onPressed: () async {
              await _goals.complete(g.id);
              await _reload();
            },
          ),
        );
      },
    );
  }

  Widget _empty(String m) => Center(child: Text(m, style: const TextStyle(color: Colors.white54)));
}
