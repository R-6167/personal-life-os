import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../../services/day_planner.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'task_detail_screen.dart';

/// Phase 2 — daily/weekly planning: free time, schedule sessions, agenda.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final _plan = PlanningRepository(AppDatabase.instance);
  final _tasks = TaskRepository(AppDatabase.instance);
  DateTime _day = DateTime.now();
  bool _loading = true;
  int _freeMin = 0;
  List<Map<String, Object?>> _blocks = [];
  List<Task> _scheduled = [];
  List<Task> _unscheduled = [];
  List<PlanItem> _ranked = [];
  List<DateTime> _slots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final free = await _plan.availableMinutes(day: _day);
    final blocks = await _plan.listBlocksOnDay(_day);
    final scheduled = await _tasks.listScheduledOnDay(_day);
    final open = await _tasks.listOpen();
    final unscheduled = open.where((t) => t.scheduledStart == null && !t.isOverdue).take(12).toList();
    final ranked = await DayPlanner().buildPlan(limit: 8);
    final slots = await _plan.suggestSlots(day: _day, durationMinutes: 30);
    if (!mounted) return;
    setState(() {
      _freeMin = free;
      _blocks = blocks;
      _scheduled = scheduled;
      _unscheduled = unscheduled;
      _ranked = ranked;
      _slots = slots;
      _loading = false;
    });
  }

  Future<void> _scheduleTask(Task t) async {
    DateTime start = _slots.isNotEmpty
        ? _slots.first
        : DateTime(_day.year, _day.month, _day.day, DateTime.now().hour + 1);
    var minutes = t.estimatedMinutes ?? 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: Text('Schedule: ${t.title}', style: const TextStyle(color: AppTheme.silver, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('EEE d MMM HH:mm').format(start), style: const TextStyle(color: AppTheme.silver)),
                trailing: const Icon(Icons.edit_calendar, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d == null) return;
                  final tm = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
                  setLocal(() {
                    start = DateTime(d.year, d.month, d.day, tm?.hour ?? start.hour, tm?.minute ?? start.minute);
                  });
                },
              ),
              Row(
                children: [
                  Text('Duration', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.6))),
                  const Spacer(),
                  DropdownButton<int>(
                    value: minutes,
                    dropdownColor: AppTheme.metal,
                    items: const [15, 25, 30, 45, 60, 90].map((m) => DropdownMenuItem(value: m, child: Text('${m}m'))).toList(),
                    onChanged: (v) => setLocal(() => minutes = v ?? 30),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _plan.scheduleTaskSession(taskId: t.id, start: start, durationMinutes: minutes, title: t.title);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session booked')));
    }
  }

  Future<void> _completeBlock(Map<String, Object?> b) async {
    await _plan.completeBlock(b['id'] as String, completeTask: b['task_id'] != null);
    await _load();
  }

  void _shiftDay(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_freeMin / 60).floor();
    final mins = _freeMin % 60;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Plan'),
          actions: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftDay(-1)),
            TextButton(
              onPressed: () {
                setState(() => _day = DateTime.now());
                _load();
              },
              child: const Text('Today'),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftDay(1)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE, d MMMM').format(_day),
                            style: const TextStyle(color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Free time ≈ ${hours}h ${mins}m (8:00–22:00)',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13)),
                        Text('${_scheduled.length} scheduled · ${_blocks.length} blocks',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Agenda', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_blocks.isEmpty && _scheduled.isEmpty)
                    Text('No sessions yet — book from the list below',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else ...[
                    ..._blocks.map((b) {
                      final s = DateTime.fromMillisecondsSinceEpoch(b['start_at'] as int);
                      final e = DateTime.fromMillisecondsSinceEpoch(b['end_at'] as int);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: ListTile(
                            title: Text('${b['title']}', style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text('${DateFormat.Hm().format(s)}–${DateFormat.Hm().format(e)} · ${b['status']}',
                                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                            trailing: b['status'] == 'COMPLETED'
                                ? const Icon(Icons.check, color: AppTheme.amber)
                                : IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                    onPressed: () => _completeBlock(b),
                                  ),
                          ),
                        ),
                      );
                    }),
                    ..._scheduled.where((t) => !_blocks.any((b) => b['task_id'] == t.id)).map((t) {
                      final s = t.scheduledStart != null
                          ? DateTime.fromMillisecondsSinceEpoch(t.scheduledStart!)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
                            );
                            await _load();
                          },
                          child: ListTile(
                            title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(s != null ? DateFormat.Hm().format(s) : 'Scheduled',
                                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                  const Text('Suggested order', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._ranked.take(5).map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GlassCard(
                          child: ListTile(
                            dense: true,
                            title: Text(p.title, style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(p.reason,
                                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                  const Text('Unscheduled open tasks',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_unscheduled.isEmpty)
                    Text('All open work is scheduled or overdue-first',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ..._unscheduled.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: ListTile(
                              title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                              subtitle: t.dueAt != null
                                  ? Text(
                                      'Due ${DateFormat.MMMd().format(DateTime.fromMillisecondsSinceEpoch(t.dueAt!))}',
                                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                                    )
                                  : null,
                              trailing: FilledButton(
                                onPressed: () => _scheduleTask(t),
                                child: const Text('Book'),
                              ),
                            ),
                          ),
                        )),
                  if (_slots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Open slots (≈30m)',
                        style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _slots
                          .map((s) => Chip(
                                label: Text(DateFormat.Hm().format(s)),
                                backgroundColor: AppTheme.metal,
                                labelStyle: const TextStyle(color: AppTheme.silver),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
