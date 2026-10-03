import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../../services/build_my_day.dart';
import '../../services/day_planner.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'task_detail_screen.dart';

/// Build My Day — timed schedule, not just ranked suggestions.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final _plan = PlanningRepository(AppDatabase.instance);
  final _tasks = TaskRepository(AppDatabase.instance);
  final _engine = BuildMyDayEngine();

  DateTime _day = DateTime.now();
  bool _loading = true;
  bool _building = false;
  bool _applying = false;

  BuiltDay? _built;
  int _freeMin = 0;
  List<PlanItem> _ranked = [];
  List<Task> _unscheduled = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final free = await _plan.availableMinutes(day: _day);
    final open = await _tasks.listOpen();
    final unscheduled =
        open.where((t) => t.scheduledStart == null).take(10).toList();
    final ranked = await DayPlanner().buildPlan(limit: 6);
    final built = await _engine.build(day: _day);
    if (!mounted) return;
    setState(() {
      _freeMin = free;
      _unscheduled = unscheduled;
      _ranked = ranked;
      _built = built;
      _loading = false;
    });
  }

  Future<void> _rebuild() async {
    setState(() => _building = true);
    final built = await _engine.build(day: _day);
    if (!mounted) return;
    setState(() {
      _built = built;
      _building = false;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _apply() async {
    final built = _built;
    if (built == null) return;
    setState(() => _applying = true);
    final n = await _engine.apply(built);
    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(n == 0 ? 'Nothing new to apply' : 'Scheduled $n blocks onto your day')),
    );
    await _load();
  }

  Future<void> _shiftDay(int delta) async {
    setState(() => _day = _day.add(Duration(days: delta)));
    await _load();
  }

  IconData _iconFor(DaySlotKind k) {
    switch (k) {
      case DaySlotKind.event:
        return Icons.event;
      case DaySlotKind.block:
        return Icons.timelapse;
      case DaySlotKind.task:
        return Icons.check_circle_outline;
      case DaySlotKind.habit:
        return Icons.repeat;
      case DaySlotKind.routine:
        return Icons.list_alt;
      case DaySlotKind.breakSlot:
        return Icons.restaurant;
      case DaySlotKind.free:
        return Icons.hourglass_empty;
    }
  }

  Color _colorFor(DaySlotKind k) {
    switch (k) {
      case DaySlotKind.event:
        return AppTheme.woodLight;
      case DaySlotKind.task:
        return AppTheme.amber;
      case DaySlotKind.habit:
        return const Color(0xFF7CB8FF);
      case DaySlotKind.routine:
        return const Color(0xFFB8A0FF);
      case DaySlotKind.breakSlot:
        return AppTheme.silverMuted;
      case DaySlotKind.block:
        return AppTheme.amber;
      case DaySlotKind.free:
        return AppTheme.silverMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEEE, d MMM').format(_day);
    final built = _built;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Build My Day'),
          actions: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: () => _shiftDay(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: () => _shiftDay(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : RefreshIndicator(
                color: AppTheme.amber,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    Text(dayLabel,
                        style: const TextStyle(
                            color: AppTheme.silver,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      built == null
                          ? '$_freeMin min free'
                          : '${built.plannedMinutes} min planned · ${built.freeMinutes} min still free',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _building ? null : _rebuild,
                            icon: _building
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Build my day'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_applying || built == null) ? null : _apply,
                            icon: _applying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.event_available),
                            label: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Build fills free time from deadlines, estimates, calendar, routines & habits. Apply writes it to your schedule.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                    ),

                    // Timeline
                    const SizedBox(height: 18),
                    const Text('Timeline',
                        style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (built == null || built.timeline.isEmpty)
                      GlassCard(
                        child: Text(
                          'No schedule yet. Tap Build my day.',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45)),
                        ),
                      )
                    else
                      ...built.timeline.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              onTap: s.kind == DaySlotKind.task && s.entityId != null
                                  ? () {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (_) =>
                                                  TaskDetailScreen(taskId: s.entityId!)))
                                          .then((_) => _load());
                                    }
                                  : null,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: _colorFor(s.kind),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 3,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: _colorFor(s.kind),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.title,
                                          style: const TextStyle(
                                            color: AppTheme.silver,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            s.timeLabel,
                                            '${s.minutes}m',
                                            if (s.reason.isNotEmpty) s.reason,
                                            if (s.locked) 'locked',
                                          ].join(' · '),
                                          style: TextStyle(
                                            color: AppTheme.silver.withValues(alpha: 0.45),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(_iconFor(s.kind), color: _colorFor(s.kind), size: 18),
                                ],
                              ),
                            ),
                          )),

                    // Unplaced
                    if (built != null && built.unplaced.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Could not fit today',
                          style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...built.unplaced.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GlassCard(
                              child: Text(
                                '${c.title} · ${c.durationMin}m · ${c.reason}',
                                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7)),
                              ),
                            ),
                          )),
                    ],

                    // Quick ranked (secondary)
                    if (_ranked.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('If you only have a moment',
                          style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._ranked.take(4).map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GlassCard(
                              child: Text(
                                '${p.title} · ${p.reason}',
                                style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                              ),
                            ),
                          )),
                    ],

                    if (_unscheduled.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Unscheduled open work',
                          style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._unscheduled.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GlassCard(
                              onTap: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(taskId: t.id)))
                                    .then((_) => _load());
                              },
                              child: Text(
                                t.title,
                                style: const TextStyle(color: AppTheme.silver),
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
