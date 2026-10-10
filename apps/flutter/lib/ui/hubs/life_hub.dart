import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/routine_repository.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../screens/calendar_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/needs_attention_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/planning_screen.dart';
import '../screens/practical_life_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/routine_detail_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/life_areas_screen.dart';
import '../screens/wellness_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class LifeHub extends StatefulWidget {
  const LifeHub({
    super.key,
    required this.goals,
    required this.habits,
    required this.notes,
    required this.projects,
    required this.onChanged,
    this.routines = const [],
  });

  final List<Goal> goals;
  final List<Habit> habits;
  final List<Note> notes;
  final List<Project> projects;
  final List<Routine> routines;
  final Future<void> Function() onChanged;

  @override
  State<LifeHub> createState() => _LifeHubState();
}

class _LifeHubState extends State<LifeHub> {
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadPractical();
  }

  Future<void> _loadPractical() async {
    final ext = ExtendedRepository(AppDatabase.instance);
    final p = await ext.listPractical();
    final d = await ext.listDocuments();
    if (mounted) {
      setState(() {
        _practical = p;
        _docs = d;
      });
    }
  }

  List<String> get _attention {
    final now = DateTime.now().millisecondsSinceEpoch;
    final week = now + const Duration(days: 28).inMilliseconds;
    final items = <String>[];
    for (final d in _docs) {
      final exp = d['expires_at'] as int?;
      if (exp != null && exp <= week) {
        final days = ((exp - now) / Duration.millisecondsPerDay).ceil();
        items.add("${d['title']} expires in ${days < 0 ? 'past due' : '$days days'}");
      }
    }
    for (final p in _practical) {
      final due = p['due_at'] as int?;
      if (due != null && due <= week) {
        items.add("${p['title']} needs attention");
      }
    }
    return items.take(5).toList();
  }

  Widget _navCard(
  icon: Icons.category_outlined,
  title: 'Life areas',
  subtitle: 'Configure domains of life',
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LifeAreasScreen()),
    );
  },
),
_navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppTheme.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.silverMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attention = _attention;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _navCard(
          icon: Icons.priority_high,
          title: 'Needs attention',
          subtitle: 'Recurring + practical duties',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NeedsAttentionScreen()))
                .then((_) => widget.onChanged());
          },
        ),
        _navCard(
          icon: Icons.favorite_outline,
          title: 'Health & wellness',
          subtitle: 'Check-in · sleep · mood',
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WellnessScreen()));
          },
        ),
        _navCard(
          icon: Icons.schedule,
          title: 'Schedule',
          subtitle: 'Day grid · drag & drop time',
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleScreen()));
          },
        ),
        _navCard(
          icon: Icons.view_timeline_outlined,
          title: 'Day plan',
          subtitle: 'Build my day · sessions',
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanningScreen()));
          },
        ),
        _navCard(
          icon: Icons.calendar_month,
          title: 'Calendar',
          subtitle: 'Events & month grid',
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
          },
        ),
        _navCard(
          icon: Icons.home_repair_service_outlined,
          title: 'Practical',
          subtitle: 'Documents · vehicle · shopping',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PracticalLifeScreen()))
                .then((_) {
              _loadPractical();
              return widget.onChanged();
            });
          },
        ),
        if (attention.isNotEmpty) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Heads-up', style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...attention.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $a', style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _header(context, 'Goals', AddKind.goal),
        if (widget.goals.isEmpty)
          _empty('No goals yet.')
        else
          ...widget.goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id)))
                        .then((_) => widget.onChanged());
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(g.title, style: const TextStyle(color: AppTheme.silver)),
                    trailing: IconButton(
                      icon: const Icon(Icons.flag, color: AppTheme.amber),
                      onPressed: () async {
                        await GoalRepository(AppDatabase.instance).complete(g.id);
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 8),
        _header(context, 'Projects', AddKind.project),
        if (widget.projects.isEmpty)
          _empty('No projects yet.')
        else
          ...widget.projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)))
                        .then((_) => widget.onChanged());
                  },
                  child: Text(p.title, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                ),
              )),
        const SizedBox(height: 8),
        _header(context, 'Habits', AddKind.habit),
        if (widget.habits.isEmpty)
          _empty('No habits yet.')
        else
          ...widget.habits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.id)))
                        .then((_) => widget.onChanged());
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(h.title, style: const TextStyle(color: AppTheme.silver)),
                    trailing: IconButton(
                      icon: const Icon(Icons.done_all, color: AppTheme.amber),
                      onPressed: () async {
                        await HabitRepository(AppDatabase.instance).markDoneToday(h.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged ${h.title}')));
                        }
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Routines', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final c = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.metal,
                    title: const Text('New routine', style: TextStyle(color: AppTheme.silver)),
                    content: TextField(
                      controller: c,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.silver),
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  final r = await RoutineRepository(AppDatabase.instance).create(name: name);
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RoutineDetailScreen(routineId: r.id)),
                    );
                  }
                  await widget.onChanged();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
        if (widget.routines.isEmpty)
          _empty('No routines yet.')
        else
          ...widget.routines.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => RoutineDetailScreen(routineId: r.id)))
                        .then((_) => widget.onChanged());
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(r.name, style: const TextStyle(color: AppTheme.silver)),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: AppTheme.amber),
                      onPressed: () async {
                        await RoutineRepository(AppDatabase.instance).completeToday(r.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Completed ${r.name}')));
                        }
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 8),
        _header(context, 'Notes', AddKind.note),
        if (widget.notes.isEmpty)
          _empty('No notes yet.')
        else
          ...widget.notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: n.id)),
                    );
                  },
                  child: Text(
                    n.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.silver),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _header(BuildContext context, String label, AddKind kind) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final ok = await showCreateForm(context, kind);
                if (ok) await widget.onChanged();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );

  Widget _empty(String m) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(m, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35))),
      );
}
