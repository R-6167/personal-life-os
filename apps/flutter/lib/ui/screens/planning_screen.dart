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

/// Payload for drag-and-drop scheduling.
class _DragPayload {
  final String id;
  final String title;
  final DaySlotKind kind;
  final int durationMin;
  final bool fromUnscheduled;
  final DaySlot? existing;

  const _DragPayload({
    required this.id,
    required this.title,
    required this.kind,
    required this.durationMin,
    this.fromUnscheduled = false,
    this.existing,
  });
}

/// Build My Day — timed schedule with manual drag-and-drop.
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
  int? _hoverHour; // which drop hour is highlighted

  static const _dayStartHour = 8;
  static const _dayEndHour = 22;

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
        open.where((t) => t.scheduledStart == null).take(12).toList();
    final ranked = await DayPlanner().buildPlan(limit: 6);
    final built = await _engine.build(day: _day);
    if (!mounted) return;
    setState(() {
      _freeMin = free;
      _unscheduled = unscheduled;
      _ranked = ranked;
      _built = built;
      _loading = false;
      _hoverHour = null;
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
      SnackBar(
          content: Text(
              n == 0 ? 'Nothing new to apply' : 'Scheduled $n blocks onto your day')),
    );
    await _load();
  }

  Future<void> _shiftDay(int delta) async {
    setState(() => _day = _day.add(Duration(days: delta)));
    await _load();
  }

  DateTime _atHour(int hour, {int minute = 0}) =>
      DateTime(_day.year, _day.month, _day.day, hour, minute);

  /// Snap drop to :00 or :30 within the hour row.
  DateTime _snapDrop(int hour, Offset? local, double rowHeight) {
    var minute = 0;
    if (local != null && rowHeight > 0) {
      final frac = (local.dy / rowHeight).clamp(0.0, 0.99);
      minute = frac < 0.5 ? 0 : 30;
    }
    return _atHour(hour, minute: minute);
  }

  Future<void> _onDrop(_DragPayload payload, int hour, {Offset? local, double rowHeight = 56}) async {
    final start = _snapDrop(hour, local, rowHeight);
    final duration = payload.durationMin.clamp(15, 180);

    // Optimistic local reorder for built timeline
    _optimisticMove(payload, start, duration);

    try {
      if (payload.fromUnscheduled || payload.kind == DaySlotKind.task) {
        if (payload.fromUnscheduled) {
          await _plan.dropTaskOntoDay(
            taskId: payload.id,
            start: start,
            durationMinutes: duration,
            title: payload.title,
          );
        } else {
          await _plan.rescheduleTaskSession(
            taskId: payload.id,
            start: start,
            durationMinutes: duration,
          );
        }
      } else if (payload.kind == DaySlotKind.block ||
          payload.kind == DaySlotKind.habit ||
          payload.kind == DaySlotKind.routine) {
        // Prefer move by block id when locked block; else create focus block
        final blockId = payload.existing?.entityId;
        if (payload.kind == DaySlotKind.block && blockId != null && payload.existing?.locked == true) {
          await _plan.moveBlock(blockId: blockId, start: start, durationMinutes: duration);
        } else {
          await _plan.addFocusBlock(
            start: start,
            durationMinutes: duration,
            title: payload.kind == DaySlotKind.habit
                ? 'Habit: ${payload.title}'
                : payload.kind == DaySlotKind.routine
                    ? 'Routine: ${payload.title}'
                    : payload.title,
          );
        }
      }
      // Calendar events: do not move via this path
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not move: $e')),
        );
      }
    }
    await _load();
  }

  void _optimisticMove(_DragPayload payload, DateTime start, int duration) {
    final built = _built;
    if (built == null) return;
    final end = start.add(Duration(minutes: duration));
    final slots = List<DaySlot>.from(built.slots);
    slots.removeWhere((s) => s.entityId == payload.id && s.kind == payload.kind);
    slots.add(DaySlot(
      start: start,
      end: end,
      title: payload.title,
      kind: payload.kind,
      entityId: payload.id,
      reason: 'Moved manually',
      locked: false,
      priority: payload.existing?.priority ?? 50,
    ));
    slots.sort((a, b) => a.start.compareTo(b.start));
    setState(() {
      _built = BuiltDay(
        day: built.day,
        slots: slots,
        unplaced: built.unplaced.where((u) => u.id != payload.id).toList(),
        freeMinutes: built.freeMinutes,
        plannedMinutes: built.plannedMinutes,
        dayStartHour: built.dayStartHour,
        dayEndHour: built.dayEndHour,
      );
      if (payload.fromUnscheduled) {
        _unscheduled = _unscheduled.where((t) => t.id != payload.id).toList();
      }
    });
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

  bool _canDrag(DaySlot s) {
    // Calendar events stay fixed; everything else can be moved.
    return s.kind != DaySlotKind.event;
  }

  Widget _draggableSlot(DaySlot s) {
    final payload = _DragPayload(
      id: s.entityId ?? s.title,
      title: s.title,
      kind: s.kind,
      durationMin: s.minutes.clamp(15, 180),
      existing: s,
    );
    final card = _slotCard(s);
    if (!_canDrag(s)) return card;

    return LongPressDraggable<_DragPayload>(
      data: payload,
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 48,
          child: Opacity(opacity: 0.92, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _slotCard(DaySlot s) {
    return GlassCard(
      onTap: s.kind == DaySlotKind.task && s.entityId != null
          ? () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(taskId: s.entityId!)))
                  .then((_) => _load());
            }
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: _colorFor(s.kind),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 40,
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
                    fontSize: 14,
                  ),
                ),
                Text(
                  [
                    '${s.minutes}m',
                    if (s.reason.isNotEmpty) s.reason,
                    if (s.kind == DaySlotKind.event) 'fixed',
                    if (_canDrag(s)) 'hold to drag',
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
    );
  }

  Widget _hourRow(int hour, List<DaySlot> slotsHere) {
    const rowHeight = 56.0;
    final isHover = _hoverHour == hour;

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hoverHour = hour);
        return details.data.kind != DaySlotKind.event;
      },
      onLeave: (_) {
        if (_hoverHour == hour) setState(() => _hoverHour = null);
      },
      onAcceptWithDetails: (details) {
        final local = details.offset; // global — approximate mid-row
        setState(() => _hoverHour = null);
        _onDrop(details.data, hour, local: Offset(0, rowHeight / 3), rowHeight: rowHeight);
      },
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty || isHover;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.amber.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? AppTheme.amber.withValues(alpha: 0.45)
                  : AppTheme.silver.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: active
                        ? AppTheme.amber
                        : AppTheme.silver.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (slotsHere.isEmpty)
                SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      active ? 'Drop here' : '',
                      style: TextStyle(
                        color: AppTheme.amber.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
              else
                ...slotsHere.map((s) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: _draggableSlot(s),
                    )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEEE, d MMM').format(_day);
    final built = _built;
    final timeline = built?.timeline ?? [];

    // Group slots by start hour
    final byHour = <int, List<DaySlot>>{};
    for (final s in timeline) {
      byHour.putIfAbsent(s.start.hour, () => []).add(s);
    }

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
                      style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
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
                      'Long-press a block and drop it on an hour. Drag tasks from below onto the day.',
                      style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                    ),

                    const SizedBox(height: 16),
                    const Text('Timeline',
                        style: TextStyle(
                            color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    // Hour grid with drop targets
                    for (var h = _dayStartHour; h < _dayEndHour; h++)
                      _hourRow(h, byHour[h] ?? const []),

                    if (built != null && built.unplaced.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Could not fit today',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...built.unplaced.map((c) {
                        final payload = _DragPayload(
                          id: c.id,
                          title: c.title,
                          kind: c.kind,
                          durationMin: c.durationMin,
                          fromUnscheduled: c.kind == DaySlotKind.task,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: LongPressDraggable<_DragPayload>(
                            data: payload,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 48,
                                child: GlassCard(
                                  child: Text(c.title,
                                      style: const TextStyle(color: AppTheme.silver)),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: GlassCard(
                                child: Text('${c.title} · ${c.durationMin}m',
                                    style: const TextStyle(color: AppTheme.silver)),
                              ),
                            ),
                            child: GlassCard(
                              child: Text(
                                '${c.title} · ${c.durationMin}m · ${c.reason} · hold to drag',
                                style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    if (_unscheduled.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Unscheduled — drag onto an hour',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._unscheduled.map((t) {
                        final payload = _DragPayload(
                          id: t.id,
                          title: t.title,
                          kind: DaySlotKind.task,
                          durationMin: (t.estimatedMinutes ?? 30).clamp(15, 120),
                          fromUnscheduled: true,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: LongPressDraggable<_DragPayload>(
                            data: payload,
                            hapticFeedbackOnStart: true,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 48,
                                child: GlassCard(
                                  child: Text(t.title,
                                      style: const TextStyle(
                                          color: AppTheme.silver,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: GlassCard(
                                child: Text(t.title,
                                    style: const TextStyle(color: AppTheme.silver)),
                              ),
                            ),
                            child: GlassCard(
                              onTap: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(taskId: t.id)))
                                    .then((_) => _load());
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.drag_indicator,
                                      color: AppTheme.silverMuted, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(t.title,
                                        style: const TextStyle(color: AppTheme.silver)),
                                  ),
                                  Text(
                                    '${t.estimatedMinutes ?? 30}m',
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.4),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    if (_ranked.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('If you only have a moment',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._ranked.take(4).map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GlassCard(
                              child: Text(
                                '${p.title} · ${p.reason}',
                                style: const TextStyle(
                                    color: AppTheme.silver, fontSize: 13),
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
