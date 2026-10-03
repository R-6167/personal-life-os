import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/db_map.dart';
import '../../services/life_thread.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/life_chain.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Goal as the root of one life thread:
/// Goal → Project → Milestone → Tasks → Schedule → Activity → Progress
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
  final _threadSvc = LifeThreadService();

  @override
  void initState() {
    super.initState();
    _load();
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
    await _load();
  }

  Future<void> _addDirectTask() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Task toward this goal', style: TextStyle(color: AppTheme.silver)),
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
    await _load();
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

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'task') await _addDirectTask();
                if (v == 'complete') {
                  await _goals.complete(widget.goalId);
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'task', child: Text('Add task to goal')),
                PopupMenuItem(value: 'complete', child: Text('Mark goal complete')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addProject,
          icon: const Icon(Icons.folder_outlined),
          label: const Text('Project'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            LifeChainBanner(
              steps: const ['Goal', 'Project', 'Milestone', 'Task', 'Schedule', 'Done'],
              subtitle:
                  '${(t.progressRatio * 100).round()}% · ${t.projectsDone}/${t.projectsTotal} projects · ${t.milestonesDone}/${t.milestonesTotal} milestones · ${t.tasksDone}/${t.tasksTotal} tasks',
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dbStr(t.goal['status'], 'ACTIVE'),
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: t.progressRatio.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Projects', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (t.projects.isEmpty)
              Text('Add a project — the workstream that moves this goal.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...t.projects.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(projectId: dbStr(p['id']))))
                            .then((_) => _load());
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(dbStr(p['title']),
                                style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                          ),
                          Text(dbStr(p['status']),
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                          const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                        ],
                      ),
                    ),
                  )),
            if (t.milestones.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Milestones across projects',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...t.milestones.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            dbStr(m['status']) == 'COMPLETED' ? Icons.flag : Icons.outlined_flag,
                            color: AppTheme.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(dbStr(m['title']), style: const TextStyle(color: AppTheme.silver))),
                          Text(dbStr(m['status']),
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 12),
            const Text('Work (tasks)', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (t.tasks.isEmpty)
              Text('Tasks appear here when linked to this goal or its projects.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...t.tasks.take(12).map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(taskId: dbStr(task['id']))))
                            .then((_) => _load());
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        dense: true,
                        title: Text(dbStr(task['title']), style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(
                          [
                            dbStr(task['status']),
                            if (task['scheduled_start'] != null) 'sched ${_fmtWhen(task['scheduled_start'] as int?)}',
                          ].join(' · '),
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                        ),
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
            if (t.scheduled.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('On the calendar (next 14 days)',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...t.scheduled.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(taskId: dbStr(task['id']))))
                            .then((_) => _load());
                      },
                      child: Text(
                        '${_fmtWhen(task['scheduled_start'] as int?)}  ·  ${dbStr(task['title'])}',
                        style: const TextStyle(color: AppTheme.silver),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            const Text('Activity history',
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
