import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/note_repository.dart';
import '../data/task_repository.dart';
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

  List<Task> _taskList = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];

  final _input = TextEditingController();

  static const _titles = ['Today', 'Tasks', 'Habits', 'Goals', 'Notes'];

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
    final h = await _habits.listActive();
    final g = await _goals.listActive();
    final n = await _notes.list();
    setState(() {
      _taskList = t;
      _habitList = h;
      _goalList = g;
      _noteList = n;
    });
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
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
      case 4:
        await _notes.create(content: text);
        break;
      default:
        await _tasks.create(title: text);
    }
    _input.clear();
    await _reload();
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
                    if (_tab != 0) _composer(),
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
          NavigationDestination(icon: Icon(Icons.note_outlined), label: 'Notes'),
        ],
      ),
    );
  }

  Widget _composer() {
    final hints = {
      1: 'New task…',
      2: 'New habit…',
      3: 'New goal…',
      4: 'New note…',
    };
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
        return _taskListView();
      case 2:
        return _habitListView();
      case 3:
        return _goalListView();
      case 4:
        return _noteListView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _today() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCard('Open tasks', '${_taskList.length}'),
        _statCard('Active habits', '${_habitList.length}'),
        _statCard('Active goals', '${_goalList.length}'),
        _statCard('Notes', '${_noteList.length}'),
        const SizedBox(height: 16),
        const Text(
          'All data stays on this device. No Expo. No Metro.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      color: const Color(0xFF1f2937),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        trailing: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _taskListView() {
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

  Widget _habitListView() {
    if (_habitList.isEmpty) return _empty('No habits yet');
    return ListView.builder(
      itemCount: _habitList.length,
      itemBuilder: (_, i) {
        final h = _habitList[i];
        return ListTile(
          title: Text(h.title, style: const TextStyle(color: Colors.white)),
          subtitle: const Text('Tap check = done today', style: TextStyle(color: Colors.white38, fontSize: 11)),
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
        );
      },
    );
  }

  Widget _goalListView() {
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

  Widget _noteListView() {
    if (_noteList.isEmpty) return _empty('No notes');
    return ListView.builder(
      itemCount: _noteList.length,
      itemBuilder: (_, i) {
        final n = _noteList[i];
        return ListTile(
          title: Text(
            n.title?.isNotEmpty == true ? n.title! : n.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _empty(String msg) => Center(
        child: Text(msg, style: const TextStyle(color: Colors.white54)),
      );
}
