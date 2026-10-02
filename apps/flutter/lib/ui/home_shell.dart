import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/task_repository.dart';
import '../domain/models.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _repo = TaskRepository(AppDatabase.instance);
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppDatabase.instance.database;
      final tasks = await _repo.listOpen();
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    await _repo.create(title: title);
    _controller.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Life OS', style: TextStyle(fontSize: 18)),
            Text('Offline · contract SQLite', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
      body: _loading
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'New task…',
                                hintStyle: TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Color(0xFF1f2937),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _addTask(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _tasks.isEmpty
                          ? const Center(
                              child: Text(
                                'No open tasks\nAdd one above — stored on device only.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _tasks.length,
                              itemBuilder: (context, i) {
                                final t = _tasks[i];
                                return ListTile(
                                  title: Text(t.title, style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(t.status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent),
                                    onPressed: () async {
                                      await _repo.complete(t.id);
                                      await _reload();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
