import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/milestone_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/db_map.dart';
import '../../services/life_thread.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/life_chain.dart';
import 'goal_detail_screen.dart';
import 'task_detail_screen.dart';

/// Project in the life thread:
/// Goal → **Project** → Milestone → Tasks → Schedule → Activity
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  ProjectThread? _thread;
  bool _loading = true;

  final _projects = ProjectRepository(AppDatabase.instance);
  final _milestonesRepo = MilestoneRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);
  final _threadSvc = LifeThreadService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _threadSvc.forProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _thread = t;
      _loading = false;
    });
  }

  Future<void> _addTask() async {
    final titleCtrl = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Task in this project', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, titleCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (submitted == null || submitted.isEmpty) return;
    final goalId = dbStrOrNull(_thread?.project['goal_id']);
    await _tasksRepo.create(
      title: submitted,
      projectId: widget.projectId,
      goalId: goalId,
    );
    await _load();
  }

  Future<void> _addMilestone() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Milestone', style: TextStyle(color: AppTheme.silver)),
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
    await _milestonesRepo.create(projectId: widget.projectId, title: title);
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
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Project not found')));
    }
    final title = dbStr(t.project['title'], 'Project');
    final goalTitle = t.goal != null ? dbStr(t.goal!['title']) : null;
    final goalId = t.goal != null ? dbStr(t.goal!['id']) : null;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Complete project',
              onPressed: () async {
                await _projects.complete(widget.projectId);
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTask,
          icon: const Icon(Icons.add),
          label: const Text('Task'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            LifeChainBanner(
              steps: const ['Goal', 'Project', 'Milestone', 'Task', 'Schedule', 'Done'],
              subtitle:
                  '${(t.progressRatio * 100).round()}% · ${t.milestonesDone}/${t.milestonesTotal} milestones · ${t.tasksDone}/${t.tasksTotal} tasks',
            ),
            if (goalTitle != null && goalId != null) ...[
              const SizedBox(height: 8),
              GlassCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goalId)),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppTheme.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Part of goal: $goalTitle',
                        style: const TextStyle(color: AppTheme.silver),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dbStr(t.project['status'], 'ACTIVE'),
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: t.progressRatio,
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Milestones', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addMilestone, child: const Text('Add')),
              ],
            ),
            if (t.milestones.isEmpty)
              Text('Milestones mark stages toward finishing the project.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...t.milestones.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        title: Text(dbStr(m['title']), style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(dbStr(m['status']),
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        trailing: dbStr(m['status']) != 'COMPLETED'
                            ? IconButton(
                                icon: const Icon(Icons.flag, color: AppTheme.amber),
                                onPressed: () async {
                                  await _milestonesRepo.complete(dbStr(m['id']));
                                  await _load();
                                },
                              )
                            : const Icon(Icons.flag, color: AppTheme.amber),
                      ),
                    ),
                  )),
            const SizedBox(height: 12),
            const Text('Tasks', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (t.tasks.isEmpty)
              Text('Add tasks — they feed schedule, calendar, and goal progress.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...t.tasks.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: dbStr(task['id']))),
                        );
                        await _load();
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        title: Text(dbStr(task['title']), style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(
                          [
                            dbStr(task['status']),
                            if (task['scheduled_start'] != null) 'sched ${_fmtWhen(task['scheduled_start'] as int?)}',
                          ].join(' · '),
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                        ),
                        trailing: dbStr(task['status']) == 'COMPLETED'
                            ? const Icon(Icons.check_circle, color: AppTheme.amber)
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                onPressed: () async {
                                  await _tasksRepo.complete(dbStr(task['id']));
                                  await _load();
                                },
                              ),
                      ),
                    ),
                  )),
            if (t.scheduled.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Scheduled (next 14 days)',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...t.scheduled.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
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
