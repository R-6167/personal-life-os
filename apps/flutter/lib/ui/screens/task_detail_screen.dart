import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../services/app_data_bus.dart';
import '../../services/feedback_service.dart';
import '../../services/recurrence_engine.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/work_session_panel.dart';

/// Full task workspace with recurrence control.
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
  RecurrenceRule? _rule;
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
    final rule = await _tasks.getRecurrenceRule(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = t;
      _description = d;
      _projectOptions = projects;
      _deps = deps;
      _rule = rule;
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
    AppDataBus.instance.tasksChanged();
    setState(() => _editing = false);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
    }
  }

  String _freqLabel(RecurrenceFrequency f) {
    switch (f) {
      case RecurrenceFrequency.once:
        return 'Does not repeat';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  String _ruleSummary(RecurrenceRule rule) {
    final parts = <String>[_freqLabel(rule.frequency)];
    if (rule.safeInterval > 1) parts.add('every ${rule.safeInterval}');
    if (rule.byWeekDays.isNotEmpty) {
      const names = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
      parts.add(rule.byWeekDays.map((d) => names[d] ?? '$d').join(', '));
    }
    if (rule.until != null) {
      final u = rule.until!;
      parts.add('until ${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }

  Future<void> _editRecurrence() async {
    var freq = _rule?.frequency ?? RecurrenceFrequency.weekly;
    var interval = _rule?.safeInterval ?? 1;
    final weekDays = Set<int>.from(_rule?.byWeekDays ?? const []);
    DateTime? until = _rule?.until;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.metal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.silver.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Repeat',
                        style: TextStyle(color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RecurrenceFrequency>(
                      value: freq,
                      dropdownColor: AppTheme.metal,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: RecurrenceFrequency.once, child: Text('Does not repeat')),
                        DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text('Daily')),
                        DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text('Weekly')),
                        DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                        DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => freq = v);
                      },
                    ),
                    if (freq != RecurrenceFrequency.once) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: interval.clamp(1, 12),
                        dropdownColor: AppTheme.metal,
                        decoration: const InputDecoration(labelText: 'Every'),
                        items: [
                          for (var i = 1; i <= 12; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => interval = v);
                        },
                      ),
                    ],
                    if (freq == RecurrenceFrequency.weekly) ...[
                      const SizedBox(height: 12),
                      const Text('Days of week',
                          style: TextStyle(color: AppTheme.silverMuted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final e in [(1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri'), (6, 'Sat'), (7, 'Sun')])
                            FilterChip(
                              label: Text(e.$2),
                              selected: weekDays.contains(e.$1),
                              onSelected: (sel) {
                                setLocal(() {
                                  if (sel) {
                                    weekDays.add(e.$1);
                                  } else {
                                    weekDays.remove(e.$1);
                                  }
                                });
                              },
                              selectedColor: AppTheme.amber.withValues(alpha: 0.35),
                              labelStyle: TextStyle(
                                color: weekDays.contains(e.$1) ? AppTheme.amber : AppTheme.silver,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (freq != RecurrenceFrequency.once) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          until == null
                              ? 'No end date'
                              : 'Until ${until!.year}-${until!.month.toString().padLeft(2, '0')}-${until!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppTheme.silver),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (until != null)
                              IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.silverMuted),
                                onPressed: () => setLocal(() => until = null),
                              ),
                            IconButton(
                              icon: const Icon(Icons.event, color: AppTheme.amber),
                              onPressed: () async {
                                final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: until ?? DateTime.now().add(const Duration(days: 90)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (p != null) setLocal(() => until = p);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_rule != null)
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Clear'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == null || !mounted) return;
    if (ok == false) {
      await _tasks.clearRecurrence(widget.taskId);
      AppDataBus.instance.tasksChanged();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurrence cleared')));
      }
      return;
    }

    if (freq == RecurrenceFrequency.once) {
      await _tasks.clearRecurrence(widget.taskId);
    } else {
      final start = _due ?? DateTime.now();
      final rule = RecurrenceRule(
        dtStart: DateTime(start.year, start.month, start.day),
        frequency: freq,
        interval: interval,
        until: until,
        byWeekDays: freq == RecurrenceFrequency.weekly
            ? (weekDays.isEmpty ? [start.weekday] : weekDays.toList()..sort())
            : const [],
      );
      await _tasks.setRecurrenceRule(taskId: widget.taskId, rule: rule);
    }
    AppDataBus.instance.tasksChanged();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurrence updated')));
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
    AppDataBus.instance.tasksChanged();
    await _load();
  }

  Future<void> _scheduleSession(Task t) async {
    DateTime start = DateTime.now().add(const Duration(minutes: 15));
    var minutes = t.estimatedMinutes ?? 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: Text('Schedule: ${t.title}', style: const TextStyle(color: AppTheme.silver, fontSize: 16)),
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
                  final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d == null) return;
                  final tm = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
                  if (tm == null) return;
                  setLocal(() => start = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$minutes minutes', style: const TextStyle(color: AppTheme.silver)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => setLocal(() => minutes = (minutes - 15).clamp(15, 180)), icon: const Icon(Icons.remove)),
                    IconButton(onPressed: () => setLocal(() => minutes = (minutes + 15).clamp(15, 180)), icon: const Icon(Icons.add)),
                  ],
                ),
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
    AppDataBus.instance.tasksChanged();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session scheduled')));
    }
  }

  String _priorityLabel(int p) {
    if (p >= 2) return 'Urgent';
    if (p == 1) return 'High';
    return 'Normal';
  }

  String _dueLabel(Task t) {
    if (t.dueAt == null) return 'No due date';
    final d = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
    return 'Due ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addDependency() async {
    final candidates = await _tasks.listOpen();
    final existing = {
      for (final d in _deps) d['depends_on_task_id'] as String?,
    };
    final options = [
      for (final t in candidates)
        if (t.id != widget.taskId && !existing.contains(t.id)) t,
    ];
    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other tasks available to depend on.')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Task>(
      context: context,
      backgroundColor: AppTheme.metalDeep,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Blocked by which task?',
                  style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
            ),
            ...options.map(
              (t) => ListTile(
                title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.pop(ctx, t),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await _tasks.addDependency(taskId: widget.taskId, dependsOnTaskId: chosen.id);
      AppDataBus.instance.tasksChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add dependency: $e')),
      );
    }
  }

  Future<void> _removeDependency(String dependsOnTaskId) async {
    try {
      await _tasks.removeDependency(taskId: widget.taskId, dependsOnTaskId: dependsOnTaskId);
      AppDataBus.instance.tasksChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove dependency: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final t = _task;
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Task not found')));
    }
    final done = t.status == EntityStatus.completed;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_editing ? 'Edit task' : 'Task'),
          actions: [
            IconButton(icon: const Icon(Icons.schedule), onPressed: () => _scheduleSession(t)),
            IconButton(icon: Icon(_editing ? Icons.close : Icons.edit), onPressed: () => setState(() => _editing = !_editing)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'reschedule') {
                  await _reschedule();
                } else if (v == 'repeat') {
                  await _editRecurrence();
                } else if (v == 'complete') {
                  FeedbackService.instance.success();
                  await _tasks.complete(t.id);
                  AppDataBus.instance.tasksChanged();
                  await _load();
                } else if (v == 'reopen') {
                  await _tasks.reopen(t.id);
                  AppDataBus.instance.tasksChanged();
                  await _load();
                } else if (v == 'delete') {
                  await _tasks.delete(t.id);
                  AppDataBus.instance.tasksChanged();
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                const PopupMenuItem(value: 'repeat', child: Text('Repeat…')),
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
              const SizedBox(height: 12),
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
                      icon: const Icon(Icons.event, color: AppTheme.amber),
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
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save changes')),
            ] else ...[
              Text(t.title,
                  style: const TextStyle(
                      color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_dueLabel(t),
                  style: TextStyle(
                      color: t.isOverdue ? Colors.orangeAccent : AppTheme.silver.withValues(alpha: 0.55))),
              Text('${_priorityLabel(t.priority)} · ${t.status}',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 13)),
              if ((_description ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_description!,
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.8), height: 1.4)),
              ],
              const SizedBox(height: 16),
              GlassCard(
                onTap: _editRecurrence,
                child: ListTile(
                  title: const Text('Repeat', style: TextStyle(color: AppTheme.silver)),
                  subtitle: Text(
                    _rule == null ? 'Does not repeat · tap to set' : _ruleSummary(_rule!),
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.repeat, color: AppTheme.amber),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('Blocked by',
                        style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: _addDependency,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.amber),
                    label: const Text('Add', style: TextStyle(color: AppTheme.amber)),
                  ),
                ],
              ),
              if (_deps.isEmpty)
                Text('No blockers · this task can be scheduled freely',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12))
              else
                ..._deps.map((d) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '• ${d['depends_on_title'] ?? d['depends_on_task_id']}',
                              style: const TextStyle(color: AppTheme.silver),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove dependency',
                            icon: const Icon(Icons.close, size: 16, color: AppTheme.silver),
                            onPressed: () => _removeDependency(
                              d['depends_on_task_id'] as String,
                            ),
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 16),
              WorkSessionPanel(taskId: t.id),
            ],
          ],
        ),
      ),
    );
  }
}
