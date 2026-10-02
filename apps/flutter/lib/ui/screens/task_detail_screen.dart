import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Full task workspace: view, edit, reschedule, complete, reopen, delete, dependencies.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _tasks = TaskRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);

  Task? _task;
  String? _description;
  List<Project> _projectOptions = [];
  List<Map<String, Object?>> _deps = [];
  bool _loading = true;
  bool _editing = false;

  late TextEditingController _title;
  late TextEditingController _desc;
  int _priority = 0;
  DateTime? _due;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _desc = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await _tasks.getById(widget.taskId);
    final d = await _tasks.descriptionOf(widget.taskId);
    final projects = await _projects.listActive();
    final deps = await _tasks.dependencies(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = t;
      _description = d;
      _projectOptions = projects;
      _deps = deps;
      if (t != null) {
        _title.text = t.title;
        _desc.text = d ?? '';
        _priority = t.priority;
        _projectId = t.projectId;
        _due = t.dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final dueMs = _due == null
        ? null
        : DateTime(_due!.year, _due!.month, _due!.day, 23, 59).millisecondsSinceEpoch;
    await _tasks.update(
      id: widget.taskId,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      priority: _priority,
      dueAt: dueMs,
      clearDue: _due == null,
      projectId: _projectId ?? '',
    );
    setState(() => _editing = false);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
    }
  }

  Future<void> _reschedule() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _tasks.reschedule(widget.taskId, picked);
    await _load();
  }

  Future<void> _scheduleSession(Task t) async {
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    var minutes = t.estimatedMinutes ?? 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Schedule session', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver),
                ),
                trailing: const Icon(Icons.edit_calendar, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(
                      context: ctx, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d == null) return;
                  final tm = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
                  setLocal(() {
                    start = DateTime(d.year, d.month, d.day, tm?.hour ?? start.hour, tm?.minute ?? start.minute);
                  });
                },
              ),
              DropdownButton<int>(
                value: minutes,
                dropdownColor: AppTheme.metal,
                items: const [15, 25, 30, 45, 60, 90]
                    .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                    .toList(),
                onChanged: (v) => setLocal(() => minutes = v ?? 30),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await PlanningRepository(AppDatabase.instance).scheduleTaskSession(
      taskId: t.id,
      start: start,
      durationMinutes: minutes,
      title: t.title,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session scheduled')));
    }
  }

  Future<void> _makeRecurring(Task t) async {
    var freq = 'DAILY';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Repeat', style: TextStyle(color: AppTheme.silver)),
          content: DropdownButtonFormField<String>(
            value: freq,
            dropdownColor: AppTheme.metal,
            items: const [
              DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
              DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
            ],
            onChanged: (v) => setLocal(() => freq = v ?? 'DAILY'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _tasks.setRecurrence(taskId: t.id, frequency: freq);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repeats $freq')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Delete task?', style: TextStyle(color: AppTheme.silver)),
        content: const Text(
          'It will leave your open lists. Activity history is kept.',
          style: TextStyle(color: AppTheme.silver),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _tasks.delete(widget.taskId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addBlocker() async {
    final open = await _tasks.listOpen();
    final others = open.where((t) => t.id != widget.taskId).toList();
    if (!mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other open tasks to depend on')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Task>(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Blocked by…', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
            ),
            ...others.map(
              (t) => ListTile(
                title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.pop(ctx, t),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _tasks.addDependency(taskId: widget.taskId, dependsOnTaskId: picked.id);
    await _load();
  }

  String _priorityLabel(int p) => switch (p) {
        2 => 'Urgent',
        1 => 'High',
        _ => 'Normal',
      };

  String _dueLabel(Task t) {
    if (t.dueAt == null) return 'No due date';
    final d = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
    final s =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (t.isOverdue) return 'Overdue · $s';
    if (t.isDueToday) return 'Due today · $s';
    return 'Due $s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final t = _task;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }
    final done = t.status == EntityStatus.completed;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_editing ? 'Edit task' : 'Task'),
          actions: [
            IconButton(
              tooltip: 'Schedule',
              icon: const Icon(Icons.schedule),
              onPressed: () => _scheduleSession(t),
            ),
            IconButton(
              tooltip: 'Repeat',
              icon: const Icon(Icons.repeat),
              onPressed: () => _makeRecurring(t),
            ),
            if (!_editing)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() => _editing = true),
              ),
            if (_editing)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _save,
              ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'reschedule') {
                  await _reschedule();
                } else if (v == 'complete') {
                  await _tasks.complete(t.id);
                  await _load();
                } else if (v == 'reopen') {
                  await _tasks.reopen(t.id);
                  await _load();
                } else if (v == 'delete') {
                  await _confirmDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                if (!done) const PopupMenuItem(value: 'complete', child: Text('Mark complete')),
                if (done) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_editing) ...[
              TextField(
                controller: _title,
                style: const TextStyle(color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _priority,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Normal')),
                  DropdownMenuItem(value: 1, child: Text('High')),
                  DropdownMenuItem(value: 2, child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 0),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _due == null
                      ? 'No due date'
                      : 'Due ${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_due != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.silverMuted),
                        onPressed: () => setState(() => _due = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppTheme.amber),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _due ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _due = p);
                      },
                    ),
                  ],
                ),
              ),
              if (_projectOptions.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _projectId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._projectOptions.map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.title)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save changes')),
            ] else ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: const TextStyle(
                            color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(label: Text(t.status)),
                        Chip(label: Text(_priorityLabel(t.priority))),
                        Chip(
                          label: Text(_dueLabel(t)),
                          backgroundColor: t.isOverdue ? Colors.red.withValues(alpha: 0.25) : null,
                        ),
                      ],
                    ),
                    if ((_description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_description!, style: const TextStyle(color: AppTheme.silver, height: 1.4)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!done)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _tasks.complete(t.id);
                          await _load();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _tasks.reopen(t.id);
                          await _load();
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('Reopen'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scheduleSession(t),
                      icon: const Icon(Icons.schedule),
                      label: const Text('Schedule'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _reschedule,
                icon: const Icon(Icons.event),
                label: const Text('Change due date'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Blocked by',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: _addBlocker, child: const Text('Add')),
                ],
              ),
              if (_deps.isEmpty)
                Text(
                  'No dependencies — this task is free to start.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
                )
              else
                ..._deps.map(
                  (d) => ListTile(
                    dense: true,
                    title: Text('${d['depends_on_title']}', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: const Text('must finish first',
                        style: TextStyle(color: AppTheme.silverMuted, fontSize: 11)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
