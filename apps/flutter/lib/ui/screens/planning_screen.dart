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

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final _plan = PlanningRepository(AppDatabase.instance);
  final _engine = BuildMyDayEngine();
  BuiltDay? _undoBuilt;
  List<Task>? _undoUnscheduled;
  String? _undoLabel;
  final _tasks = TaskRepository(AppDatabase.instance);
  final _dayPlanner = DayPlannerService();

  DateTime _day = DateTime.now();
  BuiltDay? _built;
  List<Task> _unscheduled = [];
  List<PrioritizedItem> _ranked = [];
  int _freeMin = 0;
  bool _loading = true;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && _built == null) setState(() => _loading = true);
    final built = await _engine.build(day: _day);
    final free = await _plan.availableMinutes(day: _day);
    final open = await _tasks.listOpen();
    final scheduledIds = built.timeline
        .where((s) => s.kind == DaySlotKind.task && s.entityId != null)
        .map((s) => s.entityId!)
        .toSet();
    final unscheduled = open.where((t) => !scheduledIds.contains(t.id)).toList();
    final ranked = await _dayPlanner.rankForToday();
    if (!mounted) return;
    setState(() {
      _built = built;
      _freeMin = free;
      _unscheduled = unscheduled;
      _ranked = ranked;
      _loading = false;
    });
  }

  Future<void> _rebuild() async {
    setState(() => _building = true);
    final built = await _engine.build(day: _day);
    final n = await _engine.apply(built);
    await _load();
    if (!mounted) return;
    setState(() => _building = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'No new sessions applied (day may already be full or blocked)'
              : 'Applied $n timed session${n == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  void _shiftDay(int delta) {
    setState(() {
      _day = _day.add(Duration(days: delta));
    });
    _load();
  }

  DateTime _snapDrop(int hour, Offset? local, double rowHeight) {
    var minute = 0;
    if (local != null && rowHeight > 0) {
      final frac = (local.dy / rowHeight).clamp(0.0, 0.99);
      minute = ((frac * 60) / 15).floor() * 15;
    }
    return DateTime(_day.year, _day.month, _day.day, hour, minute);
  }

  Future<void> _onDrop(_DragPayload payload, int hour,
      {Offset? local, double rowHeight = 56}) async {
    final start = _snapDrop(hour, local, rowHeight);
    final duration = payload.durationMin.clamp(15, 180);

    final conflict = await _plan.conflictsWithLocked(
      start: start,
      durationMinutes: duration,
      ignoreTaskId: payload.kind == DaySlotKind.task ? payload.id : null,
      ignoreBlockId: payload.kind == DaySlotKind.block ? payload.id : null,
    );
    if (conflict && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Slot overlap'),
          content: Text(
            '${payload.title} overlaps something already on the calendar. Place anyway?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Place')),
          ],
        ),
      );
      if (ok != true) return;
    }

    _optimisticMove(payload, start, duration);

    try {
      if (payload.kind == DaySlotKind.block && payload.existing != null) {
        final blockId = payload.existing!.entityId;
        if (blockId != null) {
          await _plan.moveBlock(
            blockId: blockId,
            start: start,
            durationMinutes: duration,
          );
        }
      } else if (payload.kind == DaySlotKind.task) {
        if (payload.existing != null || !payload.fromUnscheduled) {
          await _plan.rescheduleTaskSession(
            taskId: payload.id,
            start: start,
            durationMinutes: duration,
          );
        } else {
          await _plan.scheduleTaskSession(
            taskId: payload.id,
            start: start,
            durationMinutes: duration,
            title: payload.title,
          );
        }
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
      _offerUndo(payload.title);
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

  void _offerUndo(String title) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled: $title'),
        action: _undoBuilt == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: _undoLastDrop,
              ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _undoLastDrop() async {
    final snap = _undoBuilt;
    final unsched = _undoUnscheduled;
    if (snap == null) return;
    setState(() {
      _built = snap;
      if (unsched != null) _unscheduled = unsched;
      _undoBuilt = null;
      _undoUnscheduled = null;
      _undoLabel = null;
    });
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reloaded day — re-run Build My Day if needed')),
      );
    }
  }

  void _optimisticMove(_DragPayload payload, DateTime start, int duration) {
    final built = _built;
    if (built == null) return;
    _undoBuilt = built;
    _undoUnscheduled = List<Task>.from(_unscheduled);
    _undoLabel = payload.title;
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
        return const Color(0xFF9B8CFF);
      case DaySlotKind.block:
        return AppTheme.silverMuted;
      case DaySlotKind.breakSlot:
        return AppTheme.wood;
      case DaySlotKind.free:
        return AppTheme.silverMuted;
    }
  }

  Widget _draggableSlot(DaySlot s) {
    final card = _slotCard(s);
    if (s.locked && s.kind == DaySlotKind.event) return card;
    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(
        id: s.entityId ?? s.title,
        title: s.title,
        kind: s.kind,
        durationMin: s.minutes.clamp(15, 180),
        existing: s,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: Opacity(opacity: 0.9, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _slotCard(DaySlot s) {
    final color = _colorFor(s.kind);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(_iconFor(s.kind), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    color: AppTheme.silver,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${s.timeLabel}${s.reason.isNotEmpty ? ' · ${s.reason}' : ''}',
                  style: TextStyle(
                    color: AppTheme.silver.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (s.locked)
            Icon(Icons.lock, size: 14, color: AppTheme.silver.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _hourRow(int hour, List<DaySlot> slotsHere) {
    final label =
        '${hour.toString().padLeft(2, '0')}:00';
    const rowHeight = 56.0;
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        _onDrop(details.data, hour, local: Offset(0, rowHeight / 3), rowHeight: rowHeight);
      },
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: rowHeight),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.silver.withValues(alpha: 0.08)),
            ),
            color: highlight ? AppTheme.amber.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: slotsHere.isEmpty
                    ? const SizedBox(height: rowHeight)
                    : Column(
                        children: [
                          ...slotsHere.map((s) => Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                                child: _draggableSlot(s),
                              )),
                        ],
                      ),
              ),
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

    final byHour = <int, List<DaySlot>>{};
    for (final s in timeline) {
      byHour.putIfAbsent(s.start.hour, () => []).add(s);
    }

    final startH = built?.dayStartHour ?? 8;
    final endH = built?.dayEndHour ?? 22;

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
        body: (_loading && _built == null)
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
                    if (built != null &&
                        built.timeline.isEmpty &&
                        _unscheduled.isEmpty) ...[
                      const SizedBox(height: 8),
                      GlassCard(
                        child: Text(
                          'Nothing planned for this day yet.\n'
                          'Add tasks or tap Build My Day when you have work to place.',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    if (built != null && built.unplaced.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Could not place',
                        style: TextStyle(
                          color: AppTheme.woodLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...built.unplaced.take(6).map(
                            (u) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Icon(
                                      u.reason.startsWith('Blocked')
                                          ? Icons.link_off
                                          : Icons.event_busy,
                                      size: 18,
                                      color: u.reason.startsWith('Blocked')
                                          ? Colors.redAccent
                                          : AppTheme.silverMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u.title,
                                              style: const TextStyle(
                                                  color: AppTheme.silver,
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            u.reason,
                                            style: TextStyle(
                                              color: AppTheme.silver
                                                  .withValues(alpha: 0.55),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${u.durationMin}m',
                                      style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
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
                            label: Text(_building ? 'Building…' : 'Build My Day'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var h = startH; h < endH; h++)
                      _hourRow(h, byHour[h] ?? const []),
                    if (_unscheduled.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Unscheduled',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._unscheduled.take(12).map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: LongPressDraggable<_DragPayload>(
                            data: _DragPayload(
                              id: t.id,
                              title: t.title,
                              kind: DaySlotKind.task,
                              durationMin: (t.estimatedMinutes ?? 30).clamp(15, 180),
                              fromUnscheduled: true,
                            ),
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 240,
                                child: GlassCard(
                                  child: Text(t.title,
                                      style: const TextStyle(color: AppTheme.silver)),
                                ),
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
