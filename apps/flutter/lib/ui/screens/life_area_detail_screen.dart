import 'package:flutter/material.dart';

import '../../services/app_data_bus.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/life_area_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/life_area.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'goal_detail_screen.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Overview for one life area: goals, projects, open tasks.
class LifeAreaDetailScreen extends StatefulWidget {
  const LifeAreaDetailScreen({super.key, required this.lifeAreaId});
  final String lifeAreaId;

  @override
  State<LifeAreaDetailScreen> createState() => _LifeAreaDetailScreenState();
}

class _LifeAreaDetailScreenState extends State<LifeAreaDetailScreen> {
  final _areas = LifeAreaRepository(AppDatabase.instance);
  final _goals = GoalRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _tasks = TaskRepository(AppDatabase.instance);

  LifeArea? _area;
  List<Goal> _goalList = [];
  List<Project> _projectList = [];
  List<Task> _taskList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openAfterMaybeReload(Future<void> Function() open) async {
    final generationBefore = AppDataBus.instance.generation;
    await open();
    if (!mounted) return;
    if (AppDataBus.instance.generation != generationBefore) {
      await _load();
    }
  }

  Future<void> _load() async {
    final area = await _areas.getById(widget.lifeAreaId);
    final goals = await _goals.listByLifeArea(widget.lifeAreaId);
    final projects = await _projects.listByLifeArea(widget.lifeAreaId);
    final tasks = await _tasks.listByLifeArea(widget.lifeAreaId);
    if (!mounted) return;
    setState(() {
      _area = area;
      _goalList = goals;
      _projectList = projects;
      _taskList = tasks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _area?.title ?? 'Life area';
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: Text(title, style: const TextStyle(color: AppTheme.silver)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
          : _area == null
              ? const Center(
                  child: Text('Life area not found',
                      style: TextStyle(color: AppTheme.silverMuted)))
              : RefreshIndicator(
                  color: AppTheme.amber,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if ((_area!.description ?? '').isNotEmpty) ...[
                        Text(
                          _area!.description!,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _section(
                        'Goals',
                        empty: 'No goals in this area yet.',
                        children: _goalList
                            .map(
                              (g) => _tile(
                                title: g.title,
                                subtitle: g.status,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GoalDetailScreen(goalId: g.id),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      _section(
                        'Projects',
                        empty: 'No projects in this area yet.',
                        children: _projectList
                            .map(
                              (p) => _tile(
                                title: p.title,
                                subtitle: p.status,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProjectDetailScreen(projectId: p.id),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      _section(
                        'Open tasks',
                        empty: 'No open tasks linked to this area.',
                        children: _taskList
                            .map(
                              (t) => _tile(
                                title: t.title,
                                subtitle: t.status,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: t.id),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _section(
    String heading, {
    required String empty,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: AppTheme.woodLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              empty,
              style: TextStyle(
                color: AppTheme.silver.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        child: ListTile(
          title: Text(title, style: const TextStyle(color: AppTheme.silver)),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
        ),
      ),
    );
  }
}
