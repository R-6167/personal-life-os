import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'project_detail_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  Goal? _goal;
  List<Project> _projects = [];
  List<Task> _tasks = [];
  Map<String, int> _progress = {};
  bool _loading = true;

  final _goals = GoalRepository(AppDatabase.instance);
  final _projectsRepo = ProjectRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await _goals.getById(widget.goalId);
    final p = await _projectsRepo.listByGoal(widget.goalId);
    final t = await _tasksRepo.listByGoal(widget.goalId);
    final prog = await _goals.progress(widget.goalId);
    setState(() {
      _goal = g;
      _projects = p;
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
    final g = _goal;
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Goal not found')));
    }
    final pt = _progress['projectsTotal'] ?? 0;
    final pd = _progress['projectsDone'] ?? 0;
    final tt = _progress['tasksTotal'] ?? 0;
    final td = _progress['tasksDone'] ?? 0;
    final ratio = tt == 0 ? (pt == 0 ? 0.0 : pd / pt) : td / tt;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(g.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                await _goals.complete(g.id);
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
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
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            if (title != null && title.isNotEmpty) {
              await _projectsRepo.create(title: title, goalId: g.id);
              await _load();
            }
          },
          icon: const Icon(Icons.folder_outlined),
          label: const Text('Project'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$pd/$pt projects · $td/$tt tasks',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Projects', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_projects.isEmpty)
              Text('Link a project to move this goal forward', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._projects.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)),
                        ).then((_) => _load());
                      },
                      child: Text(p.title, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    ),
                  )),
            const SizedBox(height: 16),
            const Text('Direct tasks', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_tasks.isEmpty)
              Text('No tasks linked to this goal yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._tasks.map((t) => ListTile(
                    title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(t.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                    trailing: t.status != 'COMPLETED'
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                            onPressed: () async {
                              await _tasksRepo.complete(t.id);
                              await _load();
                            },
                          )
                        : null,
                  )),
          ],
        ),
      ),
    );
  }
}
