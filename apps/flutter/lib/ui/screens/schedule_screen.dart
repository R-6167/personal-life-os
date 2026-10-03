import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/db_map.dart';
import '../../domain/models.dart';
import '../../services/build_my_day.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'task_detail_screen.dart';

class _SchedDrag {
  final String id;
  final String title;
  final DaySlotKind kind;
  final int durationMin;
  final bool fromTray;
  final String? blockId;

  const _SchedDrag({
    required this.id,
    required this.title,
    required this.kind,
    required this.durationMin,
    this.fromTray = false,
    this.blockId,
  });
}

/// Visual day/week schedule with drag-and-drop onto a continuous time grid.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _plan = PlanningRepository(AppDatabase.instance);
  final _tasks = TaskRepository(AppDatabase.instance);
  final _engine = BuildMyDayEngine();

  late DateTime _day;
  bool _loading = true;
  BuiltDay? _built;
  List<Task> _tray = [];
  List<Map<String, Object?>> _blocks = [];

  static const int _startHour = 6;
  static const int _endHour = 23;
  static const double _pxPerMin = 1.2; // 72px per hour

  final _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final n = widget.initialDay ?? DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    _load();
  }

  double get _gridHeight => (_endHour - _startHour) * 60 * _pxPerMin;

  DateTime get _dayStart => DateTime(_day.year, _day.month, _day.day, _startHour);
  DateTime get _dayEnd => DateTime(_day.year, _day.month, _day.day, _endHour);

  Future<void> _load() async {
    setState(() => _loading = true);
    final built = await _engine.build(
      day: _day,
      dayStartHour: _startHour,
      dayEndHour: _endHour,
      includeLunchBreak: true,
    );
    final open = await _tasks.listOpen();
    final tray = open.where((t) => t.scheduledStart == null).take(15).toList();
    final blocks = await _plan.listBlocksOnDay(_day);
    if (!mounted) return;
    setState(() {
      _built = built;
      _tray = tray;
      _blocks = blocks;
      _loading = false;
    });
  }

  void _shiftDay(int d) {
    setState(() => _day = _day.add(Duration(days: d)));
    _load();
  }

  double _topFor(DateTime t) {
    final mins = t.difference(_dayStart).inMinutes;
    return (mins * _pxPerMin).clamp(0.0, _gridHeight);
  }

  double _heightFor(int minutes) => (minutes * _pxPerMin).clamp(24.0, _gridHeight);

  DateTime _timeFromGlobalY(double globalY) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return _dayStart;
    final local = box.globalToLocal(Offset(0, globalY));
    var mins = (local.dy / _pxPerMin).round();
    mins = (mins / 15).round() * 15; // snap 15m
    mins = mins.clamp(0, (_endHour - _startHour) * 60 - 15);
    return _dayStart.add(Duration(minutes: mins));
  }

  Future<void> _persistDrop(_SchedDrag drag, DateTime start) async {
    final dur = drag.durationMin.clamp(15, 180);
    try {
      if (drag.kind == DaySlotKind.task || drag.fromTray) {
        if (drag.fromTray) {
          await _plan.dropTaskOntoDay(
            taskId: drag.id,
            start: start,
            durationMinutes: dur,
            title: drag.title,
          );
        } else {
          await _plan.rescheduleTaskSession(
            taskId: drag.id,
            start: start,
            durationMinutes: dur,
          );
        }
      } else if (drag.blockId != null) {
        await _plan.moveBlock(
          blockId: drag.blockId!,
          start: start,
          durationMinutes: dur,
        );
      } else {
        await _plan.addFocusBlock(
          start: start,
          durationMinutes: dur,
          title: drag.title,
        );
      }
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Move failed: $e')),
        );
      }
    }
    await _load();
  }

  String? _blockIdForTask(String? taskId) {
    if (taskId == null) return null;
    for (final b in _blocks) {
      if (b['task_id'] == taskId) return b['id'] as String?;
    }
    return null;
  }

  Color _color(DaySlotKind k) {
    switch (k) {
      case DaySlotKind.event:
        return AppTheme.woodLight;
      case DaySlotKind.task:
      case DaySlotKind.block:
        return AppTheme.amber;
      case DaySlotKind.habit:
        return const Color(0xFF7CB8FF);
      case DaySlotKind.routine:
        return const Color(0xFFB8A0FF);
      case DaySlotKind.breakSlot:
        return AppTheme.silverMuted;
      case DaySlotKind.free:
        return AppTheme.silverMuted;
    }
  }

  bool _movable(DaySlot s) => s.kind != DaySlotKind.event;

  Widget _blockChip(DaySlot s) {
    final h = _heightFor(s.minutes);
    final top = _topFor(s.start);
    final color = _color(s.kind);
    final chip = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            maxLines: h < 36 ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.silver,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (h >= 36)
            Text(
              s.timeLabel,
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 10),
            ),
        ],
      ),
    );

    if (!_movable(s)) {
      return Positioned(top: top, left: 52, right: 8, height: h, child: chip);
    }

    final drag = _SchedDrag(
      id: s.entityId ?? s.title,
      title: s.title,
      kind: s.kind,
      durationMin: s.minutes,
      blockId: s.kind == DaySlotKind.block || s.kind == DaySlotKind.habit || s.kind == DaySlotKind.routine
          ? (s.entityId)
          : _blockIdForTask(s.entityId),
    );

    return Positioned(
      top: top,
      left: 52,
      right: 8,
      height: h,
      child: LongPressDraggable<_SchedDrag>(
        data: drag,
        hapticFeedbackOnStart: true,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 80,
            height: h,
            child: Opacity(opacity: 0.9, child: chip),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: chip),
        child: GestureDetector(
          onTap: s.kind == DaySlotKind.task && s.entityId != null
              ? () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(taskId: s.entityId!)))
                      .then((_) => _load());
                }
              : null,
          child: chip,
        ),
      ),
    );
  }

  Widget _timeGrid(List<DaySlot> slots) {
    return DragTarget<_SchedDrag>(
      onWillAcceptWithDetails: (d) => d.data.kind != DaySlotKind.event,
      onAcceptWithDetails: (d) {
        final start = _timeFromGlobalY(d.offset.dy);
        _persistDrop(d.data, start);
      },
      builder: (context, cand, rej) {
        final active = cand.isNotEmpty;
        return Container(
          key: _gridKey,
          height: _gridHeight,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.amber.withValues(alpha: 0.06)
                : AppTheme.metal.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? AppTheme.amber.withValues(alpha: 0.5)
                  : AppTheme.silver.withValues(alpha: 0.12),
            ),
          ),
          child: Stack(
            children: [
              // Hour lines + labels
              for (var h = _startHour; h < _endHour; h++)
                Positioned(
                  top: (h - _startHour) * 60 * _pxPerMin,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.silver.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              // Now line
              if (_isToday)
                Positioned(
                  top: _topFor(DateTime.now()),
                  left: 48,
                  right: 4,
                  child: Container(height: 2, color: AppTheme.amber.withValues(alpha: 0.85)),
                ),
              // Blocks
              ...slots.map(_blockChip),
              if (active)
                Positioned(
                  left: 56,
                  right: 12,
                  top: 8,
                  child: Text(
                    'Drop to reschedule',
                    style: TextStyle(color: AppTheme.amber.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool get _isToday {
    final n = DateTime.now();
    return n.year == _day.year && n.month == _day.month && n.day == _day.day;
  }

  Widget _weekStrip() {
    final base = _day.subtract(Duration(days: _day.weekday % 7)); // week starting Sunday-ish
    // Show 7 days centered around current
    final start = _day.subtract(const Duration(days: 3));
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (_, i) {
          final d = DateTime(start.year, start.month, start.day + i);
          final sel = d.year == _day.year && d.month == _day.month && d.day == _day.day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _day = d);
                _load();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                  color: sel ? AppTheme.amber.withValues(alpha: 0.2) : AppTheme.metal.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? AppTheme.amber : AppTheme.silver.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(d),
                      style: TextStyle(
                        color: sel ? AppTheme.amber : AppTheme.silver.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        color: AppTheme.silver,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _built?.timeline ?? [];
    final label = DateFormat('EEEE, d MMMM').format(_day);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Schedule'),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftDay(-1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftDay(1),
            ),
            IconButton(
              tooltip: 'Today',
              icon: const Icon(Icons.today),
              onPressed: () {
                final n = DateTime.now();
                setState(() => _day = DateTime(n.year, n.month, n.day));
                _load();
              },
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : RefreshIndicator(
                color: AppTheme.amber,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.silver,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _weekStrip(),
                    const SizedBox(height: 8),
                    Text(
                      'Long-press a block and drop on the grid · drag tasks from the tray',
                      style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _timeGrid(slots),
                    const SizedBox(height: 20),
                    const Text('Unscheduled tray',
                        style: TextStyle(
                            color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_tray.isEmpty)
                      Text('All open tasks are scheduled.',
                          style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.35)))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tray.map((t) {
                          final drag = _SchedDrag(
                            id: t.id,
                            title: t.title,
                            kind: DaySlotKind.task,
                            durationMin: (t.estimatedMinutes ?? 30).clamp(15, 120),
                            fromTray: true,
                          );
                          final chip = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.metal.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.amber.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.drag_indicator,
                                    size: 16, color: AppTheme.silverMuted),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    t.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.silver, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                          return LongPressDraggable<_SchedDrag>(
                            data: drag,
                            hapticFeedbackOnStart: true,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(opacity: 0.9, child: chip),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: chip),
                            child: chip,
                          );
                        }).toList(),
                      ),
                    if (_built != null && _built!.unplaced.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Suggested but not placed',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._built!.unplaced.map((c) {
                        final drag = _SchedDrag(
                          id: c.id,
                          title: c.title,
                          kind: c.kind,
                          durationMin: c.durationMin,
                          fromTray: c.kind == DaySlotKind.task,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: LongPressDraggable<_SchedDrag>(
                            data: drag,
                            feedback: Material(
                              color: Colors.transparent,
                              child: GlassCard(
                                child: Text(c.title,
                                    style: const TextStyle(color: AppTheme.silver)),
                              ),
                            ),
                            child: GlassCard(
                              child: Text(
                                '${c.title} · ${c.durationMin}m · hold to place',
                                style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
