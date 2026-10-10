import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/db_map.dart';
import '../../services/app_data_bus.dart';
import '../../services/life_thread.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/life_chain.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Goal as the higher-level structure of the Life OS:
/// GOAL → Projects → Milestones → Tasks | Habits | Progress | History
class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  GoalThread? _thread;
  bool _loading = true;

  final _goals = GoalRepository(AppDatabase.instance);
  final _projectsRepo = ProjectRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);
  final _habitsRepo = HabitRepository(AppDatabase.instance);
  final _threadSvc = LifeThreadService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openTaskDetails(String taskId) async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation != generationBefore) {
      await _load();
    }
  }

  Future<void> _openProjectDetails(String projectId) async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: projectId)),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation != generationBefore) {
      await _load();
    }
  }

  Future<void> _load() async {
    final t = await _threadSvc.forGoal(widget.goalId);
    if (!mounted) return;
    setState(() {
      _thread = t;
      _loading = false;
    });
  }

  Future<void> _addProject() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Project under this goal', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _projectsRepo.create(title: title, goalId: widget.goalId);
    AppDataBus.instance.lifeChanged();
    await _load();
  }

  Future<void> _addDirectTask() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Task on this goal', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _tasksRepo.create(title: title, goalId: widget.goalId);
    AppDataBus.instance.tasksChanged();
    await _load();
  }

  Future<void> _addHabit() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Supporting habit', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Habit title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final h = await _habitsRepo.create(title: title);
    await _threadSvc.linkHabitToGoal(goalId: widget.goalId, habitId: h.id);
    AppDataBus.instance.lifeChanged();
    await _load();
  }

  Future<void> _setTarget() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _goals.updateMeta(
      id: widget.goalId,
      targetDate: DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch,
    );
    AppDataBus.instance.lifeChanged();
    await _load();
  }

  String _fmt(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtWhen(int? ms) {
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final t = _thread;
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Goal not found')));
    }
    final title = dbStr(t.goal['title'], 'Goal');
    final desc = dbStrOrNull(t.goal['description']);
    final target = t.goal['target_date'] as int?;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'target') await _setTarget();
                if (v == 'habit') await _addHabit();
                if (v == 'task') await _addDirectTask();
                if (v == 'complete') {
                  await _goals.complete(widget.goalId);
                  AppDataBus.instance.lifeChanged();
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'target', child: Text('Set target date')),
                PopupMenuItem(value: 'habit', child: Text('Link habit')),
                PopupMenuItem(value: 'task', child: Text('Add direct task')),
                PopupMenuItem(value: 'complete', child: Text('Mark goal complete')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addProject,
          icon: const Icon(Icons.folder_open),
          label: const Text('Project'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            LifeChainBanner(
              steps: const ['Goal', 'Project', 'Milestone', 'Task', 'Schedule', 'Done'],
              subtitle:
                  '${(t.progressRatio * 100).round()}% · ${t.projectsDone}/${t.projectsTotal} projects · ${t.tasksDone}/${t.tasksTotal} tasks',
            ),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.explore, color: AppTheme.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'What am I doing toward this?',
                        style: TextStyle(
                          color: AppTheme.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.doingSummary,
                    style: const TextStyle(color: AppTheme.silver, fontSize: 14, height: 1.35),
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 8),
                    Text(desc, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: t.progressRatio,
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        dbStr(t.goal['status'], 'ACTIVE'),
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                      ),
                      const Spacer(),
                      if (target != null)
                        Text('Target ${_fmt(target)}',
                            style: const TextStyle(color: AppTheme.woodLight, fontSize: 12))
                      else
                        TextButton(
                          onPressed: _setTarget,
                          child: const Text('Set target', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (t.nextMoves.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Next moves',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...t.nextMoves.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      onTap: m.kind == 'TASK'
                          ? () => _openTaskDetails(m.id)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            m.kind == 'HABIT' ? Icons.repeat : Icons.bolt,
                            color: AppTheme.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.title,
                                    style: const TextStyle(
                                        color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                Text(m.reason,
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.45),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (m.kind == 'TASK')
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                              onPressed: () async {
                                await _tasksRepo.complete(m.id);
                                HapticFeedback.selectionClick();
                                await _load();
                              },
                            ),
                        ],
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Projects',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addProject, child: const Text('Add')),
              ],
            ),
            if (t.branches.isEmpty)
              Text(
                'Projects turn this goal into concrete work.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
              )
            else
              ...t.branches.map((b) => _ProjectTreeCard(
                    branch: b,
                    onOpen: () => _openProjectDetails(dbStr(b.project['id'])),
                    onOpenTask: (id) => _openTaskDetails(id),
                    onCompleteTask: (id) async {
                      await _tasksRepo.complete(id);
                      await _load();
                    },
                  )),
            if (t.directTasks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Direct tasks',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: _addDirectTask, child: const Text('Add')),
                ],
              ),
              ...t.directTasks.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      onTap: () => _openTaskDetails(dbStr(task['id'])),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        title:
                            Text(dbStr(task['title']), style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(dbStr(task['status']),
                            style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        trailing: dbStr(task['status']) != 'COMPLETED'
                            ? IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                onPressed: () async {
                                  await _tasksRepo.complete(dbStr(task['id']));
                                  await _load();
                                },
                              )
                            : const Icon(Icons.check_circle, color: AppTheme.amber),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Habits',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addHabit, child: const Text('Link')),
              ],
            ),
            if (t.habits.isEmpty)
              Text(
                'Habits that support this goal over time.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
              )
            else
              ...t.habits.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.repeat, color: AppTheme.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(dbStr(h['title']),
                                style: const TextStyle(color: AppTheme.silver)),
                          ),
                          Text(dbStr(h['status'], 'ACTIVE'),
                              style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                    ),
                  )),
            if (t.scheduled.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('On the calendar (next 14 days)',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...t.scheduled.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      onTap: () => _openTaskDetails(dbStr(task['id'])),
                      child: Text(
                        '${_fmtWhen(task['scheduled_start'] as int?)}  ·  ${dbStr(task['title'])}',
                        style: const TextStyle(color: AppTheme.silver),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            const Text('History',
                style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ActivityTimeline(
              items: t.activity
                  .map((a) => (label: humanEvent(a.eventType), at: a.occurredAt))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTreeCard extends StatelessWidget {
  const _ProjectTreeCard({
    required this.branch,
    required this.onOpen,
    required this.onOpenTask,
    required this.onCompleteTask,
  });

  final ProjectBranch branch;
  final VoidCallback onOpen;
  final void Function(String taskId) onOpenTask;
  final void Function(String taskId) onCompleteTask;

  @override
  Widget build(BuildContext context) {
    final p = branch.project;
    final title = dbStr(p['title']);
    final openTasks =
        branch.tasks.where((t) => dbStr(t['status']) != 'COMPLETED').take(4).toList();
    final openMs =
        branch.milestones.where((m) => dbStr(m['status']) != 'COMPLETED').take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpen,
              child: Row(
                children: [
                  const Icon(Icons.folder_open, color: AppTheme.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: AppTheme.silver, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Text(
                    '${(branch.progressRatio * 100).round()}%',
                    style: const TextStyle(color: AppTheme.amber, fontSize: 12),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                ],
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: branch.progressRatio,
              backgroundColor: AppTheme.silver.withValues(alpha: 0.12),
              color: AppTheme.amber,
              minHeight: 3,
            ),
            if (branch.nextTaskTitle != null) ...[
              const SizedBox(height: 8),
              Text(
                'Next: ${branch.nextTaskTitle}',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.65), fontSize: 12),
              ),
            ],
            if (openMs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...openMs.map((m) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 14, color: AppTheme.woodLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(dbStr(m['title']),
                              style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.7), fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
            if (openTasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...openTasks.map((task) => Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.check_circle_outline,
                              color: AppTheme.amber, size: 18),
                          onPressed: () => onCompleteTask(dbStr(task['id'])),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => onOpenTask(dbStr(task['id'])),
                            child: Text(dbStr(task['title']),
                                style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (branch.tasksTotal == 0 && branch.milestonesTotal == 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('No milestones or tasks yet — open to build the workspace.',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35), fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
