import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/export_service.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/note_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';

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
  final _export = ExportService(AppDatabase.instance);

  List<Task> _taskList = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];
  List<Project> _projectList = [];
  List<Expense> _expenseList = [];
  int _monthSpendMinor = 0;

  final _input = TextEditingController();
  final _amount = TextEditingController();

  static const _titles = ['Today', 'Tasks', 'Habits', 'Goals', 'More'];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _amount.dispose();
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
    final h = await _habits.listActive();
    final g = await _goals.listActive();
    final n = await _notes.list();
    final p = await _projects.listActive();
    final e = await _expenses.listRecent();
    final spend = await _expenses.totalMinorThisMonth();
    setState(() {
      _taskList = t;
      _habitList = h;
      _goalList = g;
      _noteList = n;
      _projectList = p;
      _expenseList = e;
      _monthSpendMinor = spend;
    });
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty && _tab != 4) return;
    switch (_tab) {
      case 1:
        await _tasks.create(title: text);
        break;
      case 2:
        await _habits.create(title: text);
        break;
      case 3:
        await _goals.create(title: text);
        break;
      default:
        break;
    }
    _input.clear();
    await _reload();
  }

  Future<void> _addExpense() async {
    final desc = _input.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (desc.isEmpty || amount == null || amount <= 0) return;
    await _expenses.create(description: desc, amountMajor: amount);
    _input.clear();
    _amount.clear();
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved offline')),
      );
    }
  }

  Future<void> _shareBackup() async {
    final json = await _export.buildBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/personal-life-os-backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Personal Life OS offline backup',
    );
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
            const Text(
              'Offline · local SQLite · contract',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          if (_tab == 4)
            IconButton(
              tooltip: 'Export backup',
              onPressed: _shareBackup,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
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
    final hints = {1: 'New task…', 2: 'New habit…', 3: 'New goal…'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hints[_tab] ?? 'Add…',
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
        ],
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
        return _more();
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
        const SizedBox(height: 8),
        const Text(
          'Focus',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statTile('Tasks', '${_taskList.length}', Icons.check_box_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Habits', '${_habitList.length}', Icons.repeat)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _statTile('Goals', '${_goalList.length}', Icons.flag_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Projects', '${_projectList.length}', Icons.folder_outlined)),
          ],
        ),
        const SizedBox(height: 8),
        _statTile('Spend this month', '${Defaults.currency} $spend', Icons.payments_outlined),
        const SizedBox(height: 20),
        const Text('Open tasks', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_taskList.isEmpty)
          const Text('Nothing open — add a task.', style: TextStyle(color: Colors.white38))
        else
          ..._taskList.take(5).map(
                (t) => Card(
                  color: const Color(0xFF1f2937),
                  child: ListTile(
                    title: Text(t.title, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent),
                      onPressed: () async {
                        await _tasks.complete(t.id);
                        await _reload();
                      },
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 16),
        const Text('Habits', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_habitList.isEmpty)
          const Text('No habits yet.', style: TextStyle(color: Colors.white38))
        else
          ..._habitList.take(5).map(
                (h) => Card(
                  color: const Color(0xFF1f2937),
                  child: ListTile(
                    title: Text(h.title, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.done_all, color: Colors.greenAccent),
                      onPressed: () async {
                        await _habits.markDoneToday(h.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged: ${h.title}')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Card(
      color: const Color(0xFF1f2937),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _listTasks() {
    if (_taskList.isEmpty) return _empty('No open tasks');
    return ListView.builder(
      itemCount: _taskList.length,
      itemBuilder: (_, i) {
        final t = _taskList[i];
        return ListTile(
          title: Text(t.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(t.status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent),
            onPressed: () async {
              await _tasks.complete(t.id);
              await _reload();
            },
          ),
        );
      },
    );
  }

  Widget _listHabits() {
    if (_habitList.isEmpty) return _empty('No habits yet');
    return ListView.builder(
      itemCount: _habitList.length,
      itemBuilder: (_, i) {
        final h = _habitList[i];
        return ListTile(
          title: Text(h.title, style: const TextStyle(color: Colors.white)),
          subtitle: const Text('Check = done today', style: TextStyle(color: Colors.white38, fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.done_all, color: Colors.greenAccent),
            onPressed: () async {
              await _habits.markDoneToday(h.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged: ${h.title}')));
              }
            },
          ),
        );
      },
    );
  }

  Widget _listGoals() {
    if (_goalList.isEmpty) return _empty('No active goals');
    return ListView.builder(
      itemCount: _goalList.length,
      itemBuilder: (_, i) {
        final g = _goalList[i];
        return ListTile(
          title: Text(g.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(g.status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
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

  Widget _more() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Projects', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _inlineAdd(
          hint: 'New project…',
          onAdd: (text) async {
            await _projects.create(title: text);
            await _reload();
          },
        ),
        ..._projectList.map(
          (p) => ListTile(
            title: Text(p.title, style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.check, color: Colors.lightBlueAccent),
              onPressed: () async {
                await _projects.complete(p.id);
                await _reload();
              },
            ),
          ),
        ),
        const Divider(color: Colors.white12),
        const Text('Notes', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _inlineAdd(
          hint: 'New note…',
          onAdd: (text) async {
            await _notes.create(content: text);
            await _reload();
          },
        ),
        ..._noteList.map(
          (n) => ListTile(
            title: Text(
              n.title?.isNotEmpty == true ? n.title! : n.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const Divider(color: Colors.white12),
        Text(
          'Money (${Defaults.currency})',
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _input,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'What for?',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF1f2937),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF1f2937),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton.filled(onPressed: _addExpense, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 8),
        ..._expenseList.take(20).map(
              (e) => ListTile(
                title: Text(e.description, style: const TextStyle(color: Colors.white)),
                trailing: Text(e.displayAmount, style: const TextStyle(color: Colors.orangeAccent)),
              ),
            ),
        const Divider(color: Colors.white12),
        ListTile(
          leading: const Icon(Icons.ios_share, color: Colors.white70),
          title: const Text('Export backup JSON', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Share offline file (contract format)', style: TextStyle(color: Colors.white38, fontSize: 11)),
          onTap: _shareBackup,
        ),
      ],
    );
  }

  Widget _inlineAdd({required String hint, required Future<void> Function(String) onAdd}) {
    final c = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: c,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1f2937),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) async {
                if (v.trim().isEmpty) return;
                await onAdd(v.trim());
                c.clear();
              },
            ),
          ),
          IconButton(
            onPressed: () async {
              final v = c.text.trim();
              if (v.isEmpty) return;
              await onAdd(v);
              c.clear();
            },
            icon: const Icon(Icons.add, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _empty(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.white54)));
}
