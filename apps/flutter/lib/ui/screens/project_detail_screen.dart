import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/milestone_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Project? _project;
  List<Milestone> _milestones = [];
  List<Task> _tasks = [];
  Map<String, int> _progress = {};
  bool _loading = true;

  final _projects = ProjectRepository(AppDatabase.instance);
  final _milestonesRepo = MilestoneRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _projects.getById(widget.projectId);
    final m = await _milestonesRepo.listForProject(widget.projectId);
    final t = await _tasksRepo.listByProject(widget.projectId);
    final prog = await _projects.progress(widget.projectId);
    setState(() {
      _project = p;
      _milestones = m;
      _tasks = t;
      _progress = prog;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final p = _project;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Project not found')));
    }
    final total = _progress['tasksTotal'] ?? 0;
    final done = _progress['tasksDone'] ?? 0;
    final ratio = total == 0 ? 0.0 : done / total;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(p.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Complete project',
              onPressed: () async {
                await _projects.complete(p.id);
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final c = TextEditingController();
                return AlertDialog(
                  backgroundColor: AppTheme.metal,
                  title: const Text('Task in this project', style: TextStyle(color: AppTheme.silver)),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.silver),
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        if (c.text.trim().isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                );
              },
            );
            // Recreate with title from a second path — use form
            if (ok == true) {
              // simple: use create forms then link — better direct:
              final titleCtrl = TextEditingController();
              final submitted = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.metal,
                  title: const Text('New task', style: TextStyle(color: AppTheme.silver)),
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
              if (submitted != null && submitted.isNotEmpty) {
                await _tasksRepo.create(title: submitted, projectId: p.id, goalId: p.goalId);
                await _load();
              }
            }
          },
          child: const Icon(Icons.add),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$done / $total tasks · ${_progress['milestonesDone']}/${_progress['milestonesTotal']} milestones',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Milestones', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
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
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, c.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (title != null && title.isNotEmpty) {
                      await _milestonesRepo.create(projectId: p.id, title: title);
                      await _load();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_milestones.isEmpty)
              Text('No milestones yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._milestones.map((m) => GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text(m.title, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(m.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.flag, color: AppTheme.amber),
                        onPressed: () async {
                          await _milestonesRepo.complete(m.id);
                          await _load();
                        },
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            const Text('Tasks', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_tasks.isEmpty)
              Text('No tasks in this project', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._tasks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(t.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        trailing: t.status == 'COMPLETED'
                            ? const Icon(Icons.check_circle, color: AppTheme.amber)
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                onPressed: () async {
                                  await _tasksRepo.complete(t.id);
                                  await _load();
                                },
                              ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
