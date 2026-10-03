import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'habit_detail_screen.dart';
import 'project_detail_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  Goal? _goal;
  Map<String, Object?>? _raw;
  List<Project> _projects = [];
  List<Task> _tasks = [];
  List<Map<String, Object?>> _habits = [];
  List<Map<String, Object?>> _reflections = [];
  Map<String, int> _progress = {};
  double _ratio = 0;
  bool _loading = true;

  final _goals = GoalRepository(AppDatabase.instance);
  final _projectsRepo = ProjectRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);
  final _habitsRepo = HabitRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await _goals.getById(widget.goalId);
    final raw = await _goals.rawById(widget.goalId);
    final p = await _projectsRepo.listByGoal(widget.goalId);
    final t = await _tasksRepo.listByGoal(widget.goalId);
    final prog = await _goals.progress(widget.goalId);
    final ratio = await _goals.progressRatio(widget.goalId);
    final habits = await _goals.listLinkedHabits(widget.goalId);
    final refl = await _goals.listReflections(widget.goalId);
    if (!mounted) return;
    setState(() {
      _goal = g;
      _raw = raw;
      _projects = p;
      _tasks = t;
      _progress = prog;
      _ratio = ratio;
      _habits = habits;
      _reflections = refl;
      _loading = false;
    });
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
    await _load();
  }

  Future<void> _setManualProgress() async {
    final c = TextEditingController(text: ((_ratio * 100).round()).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Manual progress %', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.silver),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final pct = (double.tryParse(c.text.trim()) ?? 0).clamp(0, 100) / 100;
    await _goals.updateMeta(
      id: widget.goalId,
      progressMode: ProgressMode.manual,
      manualProgress: pct,
    );
    await _load();
  }

  Future<void> _linkHabit() async {
    final all = await _habitsRepo.listActive();
    final unlinked = all.where((h) => !_habits.any((x) => x['id'] == h.id)).toList();
    if (!mounted) return;
    if (unlinked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unlinked active habits')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Habit>(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Link habit to goal', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
            ),
            ...unlinked.map((h) => ListTile(
                  title: Text(h.title, style: const TextStyle(color: AppTheme.silver)),
                  onTap: () => Navigator.pop(ctx, h),
                )),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _goals.linkHabit(picked.id, widget.goalId);
    await _load();
  }

  Future<void> _addReflection() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Reflection', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(hintText: 'What moved forward?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await _goals.addReflection(widget.goalId, c.text.trim());
    await _load();
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
    final ht = _progress['habitsTotal'] ?? 0;
    final hd = _progress['habitsDoneToday'] ?? 0;
    final target = _raw?['target_date'] as int?;
    final mode = (_raw?['progress_mode'] as String?) ?? ProgressMode.calculated;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(g.title),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'target') await _setTarget();
                if (v == 'manual') await _setManualProgress();
                if (v == 'calculated') {
                  await _goals.updateMeta(id: widget.goalId, progressMode: ProgressMode.calculated);
                  await _load();
                }
                if (v == 'complete') {
                  await _goals.complete(g.id);
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'target', child: Text('Set target date')),
                PopupMenuItem(value: 'manual', child: Text('Manual progress')),
                PopupMenuItem(value: 'calculated', child: Text('Auto progress')),
                PopupMenuItem(value: 'complete', child: Text('Mark complete')),
              ],
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
                  Text('${g.status} · $mode',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                  if (target != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Target ${_fmtDate(target)}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _ratio.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(_ratio * 100).round()}% · $pd/$pt projects · $td/$tt tasks · $hd/$ht habits today',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Projects', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_projects.isEmpty)
              Text('Link a project to move this goal forward',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._projects.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(projectId: p.id)))
                            .then((_) => _load());
                      },
                      child: Text(p.title,
                          style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    ),
                  )),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Linked habits',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _linkHabit, child: const Text('Link')),
              ],
            ),
            if (_habits.isEmpty)
              Text('Habits that support this outcome',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._habits.map((h) => ListTile(
                    title: Text('${h['title']}', style: const TextStyle(color: AppTheme.silver)),
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => HabitDetailScreen(habitId: h['id'] as String)))
                          .then((_) => _load());
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, color: AppTheme.silverMuted),
                      onPressed: () async {
                        await _goals.unlinkHabit(h['id'] as String);
                        await _load();
                      },
                    ),
                  )),
            const SizedBox(height: 16),
            const Text('Direct tasks',
                style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_tasks.isEmpty)
              Text('No tasks linked to this goal yet',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._tasks.map((t) => ListTile(
                    title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(t.status,
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Reflections',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addReflection, child: const Text('Add')),
              ],
            ),
            if (_reflections.isEmpty)
              Text('Journal progress, blockers, and wins',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ..._reflections.map((r) {
                final d = DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['content']}', style: const TextStyle(color: AppTheme.silver)),
                        const SizedBox(height: 4),
                        Text(
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
