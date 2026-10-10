import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/habit_repository.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final _repo = HabitRepository(AppDatabase.instance);
  Habit? _habit;
  String? _todayStatus;
  int _streak = 0;
  Map<String, Object?>? _schedule;
  List<Map<String, Object?>> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await _repo.getById(widget.habitId);
    if (h != null) await _repo.ensureTodayOccurrence(h.id);
    final st = await _repo.todayStatus(widget.habitId);
    final streak = await _repo.streakDays(widget.habitId);
    final sched = await _repo.scheduleOf(widget.habitId);
    final recent = await _repo.recentOccurrences(widget.habitId);
    if (!mounted) return;
    setState(() {
      _habit = h;
      _todayStatus = st;
      _streak = streak;
      _schedule = sched;
      _recent = recent;
      _loading = false;
    });
  }

  Future<void> _setFreq(String freq) async {
    await _repo.setSchedule(habitId: widget.habitId, frequency: freq);
    final schedule = await _repo.scheduleOf(widget.habitId);
    if (!mounted) return;
    // A schedule chip only changes the schedule. Keep the current screen and
    // scroll position mounted instead of reloading unrelated habit history.
    setState(() => _schedule = schedule);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final h = _habit;
    if (h == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Habit not found')));
    }
    final done = _todayStatus == 'COMPLETED';

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Habit'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'pause') await _repo.pause(h.id);
                if (v == 'resume') await _repo.resume(h.id);
                if (v == 'archive') {
                  await _repo.archive(h.id);
                  if (mounted) Navigator.pop(context, true);
                  return;
                }
                await _load();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pause', child: Text('Pause')),
                PopupMenuItem(value: 'resume', child: Text('Resume')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.title,
                      style: const TextStyle(
                          color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text(_todayStatus ?? 'No slot')),
                      Chip(label: Text('Streak $_streak')),
                      Chip(label: Text('${_schedule?['frequency'] ?? 'DAILY'}')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: done
                        ? null
                        : () async {
                            await _repo.markDoneToday(h.id);
                            await _load();
                          },
                    icon: const Icon(Icons.check),
                    label: Text(done ? 'Done today' : 'Complete'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: done
                        ? null
                        : () async {
                            await _repo.skipToday(h.id, reason: 'Flexible skip');
                            await _load();
                          },
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Schedule', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['DAILY', 'WEEKLY', 'MONTHLY'].map((f) {
                final selected = (_schedule?['frequency'] as String?) == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => _setFreq(f),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Recent', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_recent.isEmpty)
              Text('No history yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
            else
              ..._recent.map((r) {
                final d = DateTime.fromMillisecondsSinceEpoch(r['scheduled_date'] as int);
                final label =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                return ListTile(
                  dense: true,
                  title: Text(label, style: const TextStyle(color: AppTheme.silver)),
                  trailing: Text('${r['status']}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
                );
              }),
          ],
        ),
      ),
    );
  }
}
