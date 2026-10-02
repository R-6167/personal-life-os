import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../screens/calendar_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/project_detail_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class LifeHub extends StatelessWidget {
  const LifeHub({
    super.key,
    required this.goals,
    required this.habits,
    required this.notes,
    required this.projects,
    required this.onChanged,
  });

  final List<Goal> goals;
  final List<Habit> habits;
  final List<Note> notes;
  final List<Project> projects;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('Life', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Goals → projects → tasks · habits · notes · plans',
          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
        ),
        const SizedBox(height: 12),
        GlassCard(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
          },
          child: const Row(
            children: [
              Icon(Icons.calendar_month, color: AppTheme.amber),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calendar & plans', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    Text('Events, reminders, upcoming', style: TextStyle(color: AppTheme.silverMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.silverMuted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _header(context, 'Goals', AddKind.goal),
        if (goals.isEmpty)
          _empty('No goals — define an outcome you care about.')
        else
          ...goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id)))
                        .then((_) => onChanged());
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(g.title, style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(g.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.flag, color: AppTheme.amber),
                      onPressed: () async {
                        await GoalRepository(AppDatabase.instance).complete(g.id);
                        await onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 12),
        _header(context, 'Projects', AddKind.project),
        if (projects.isEmpty)
          _empty('Projects turn goals into work.')
        else
          ...projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)))
                        .then((_) => onChanged());
                  },
                  child: Text(p.title, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                ),
              )),
        const SizedBox(height: 12),
        _header(context, 'Habits', AddKind.habit),
        if (habits.isEmpty)
          _empty('No habits — start a small daily practice.')
        else
          ...habits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
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
                        await onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 12),
        _header(context, 'Notes', AddKind.note),
        if (notes.isEmpty)
          _empty('No notes yet.')
        else
          ...notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
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
                if (ok) await onChanged();
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
