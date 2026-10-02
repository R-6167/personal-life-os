import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../screens/calendar_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/planning_screen.dart';
import '../screens/project_detail_screen.dart';
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
  });

  final List<Goal> goals;
  final List<Habit> habits;
  final List<Note> notes;
  final List<Project> projects;
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
    if (items.isEmpty && _practical.isNotEmpty) {
      items.add('${_practical.length} practical item(s) on file');
    }
    return items.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final attention = _attention;
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
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanningScreen()));
          },
          child: const Row(
            children: [
              Icon(Icons.view_timeline_outlined, color: AppTheme.amber),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day plan & time', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    Text('Sessions · free time · book tasks', style: TextStyle(color: AppTheme.silverMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.silverMuted),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                    Text('Calendar', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    Text('Events, reminders, month grid', style: TextStyle(color: AppTheme.silverMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.silverMuted),
            ],
          ),
        ),
        if (attention.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Needs attention', style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...attention.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $a', style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _header(context, 'Goals', AddKind.goal),
        if (widget.goals.isEmpty)
          _empty('No goals — define an outcome you care about.')
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
                    subtitle: Text(g.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
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
        const SizedBox(height: 12),
        _header(context, 'Projects', AddKind.project),
        if (widget.projects.isEmpty)
          _empty('Projects turn goals into work.')
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
        const SizedBox(height: 12),
        _header(context, 'Habits', AddKind.habit),
        if (widget.habits.isEmpty)
          _empty('No habits — start a small daily practice.')
        else
          ...widget.habits.map((h) => Padding(
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
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Practical', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final c = TextEditingController();
                final title = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.metal,
                    title: const Text('Practical item', style: TextStyle(color: AppTheme.silver)),
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
                  await ExtendedRepository(AppDatabase.instance).addPractical(title);
                  await _loadPractical();
                  await widget.onChanged();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
        if (_practical.isEmpty)
          _empty('Documents, vehicles, chores — add what needs tracking.')
        else
          ..._practical.map((p) => ListTile(
                dense: true,
                title: Text('${p['title']}', style: const TextStyle(color: AppTheme.silver)),
                subtitle: Text('${p['type']}', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
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
