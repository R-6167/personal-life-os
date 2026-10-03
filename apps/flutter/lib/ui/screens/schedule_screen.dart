import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/task_repository.dart';
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

  const _SchedDrag({
    required this.id,
    required this.title,
    required this.kind,
    required this.durationMin,
    this.fromTray = false,
  });
}

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
  BuiltDay? _built;
  List<Task> _open = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay ?? DateTime.now();
    _day = DateTime(d.year, d.month, d.day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final built = await _engine.build(day: _day);
    final open = await _tasks.listOpen();
    if (!mounted) return;
    setState(() {
      _built = built;
      _open = open;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    if (_built == null) return;
    final n = await _engine.apply(_built!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied $n items to the calendar')),
    );
    await _load();
  }

  Future<void> _onDrop(_SchedDrag drag, int hour) async {
    final start = DateTime(_day.year, _day.month, _day.day, hour);
    final dur = drag.durationMin.clamp(15, 180);
    if (drag.kind == DaySlotKind.task) {
      await _plan.rescheduleTaskSession(
        taskId: drag.id,
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
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final built = _built;
    final byHour = <int, List<DaySlot>>{};
    if (built != null) {
      for (final s in built.timeline) {
        byHour.putIfAbsent(s.start.hour, () => []).add(s);
      }
    }

    // Keep _open referenced so analyzer is clean if tray is restored later.
    final trayHint = _open.isEmpty ? 0 : _open.length;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Schedule'),
          actions: [
            if (trayHint > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    '$trayHint open',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            TextButton(
              onPressed: built == null ? null : _apply,
              child: const Text('Apply'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat.yMMMEd().format(_day),
                            style: const TextStyle(
                                color: AppTheme.silver, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (built != null)
                          Text(
                            '${built.plannedMinutes}m planned · ${built.freeMinutes}m free',
                            style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var h = 8; h < 22; h++)
                    _hourRow(h, byHour[h] ?? const []),
                  if (built != null && built.unplaced.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Not on the plan',
                        style: TextStyle(
                            color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...built.unplaced.map((c) {
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.title,
                                          style: const TextStyle(
                                              color: AppTheme.silver,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        '${c.durationMin}m · ${c.reason}',
                                        style: TextStyle(
                                          color: c.reason.toLowerCase().contains('block')
                                              ? Colors.orangeAccent
                                              : c.reason.toLowerCase().contains('long')
                                                  ? Colors.amber
                                                  : Colors.redAccent.shade100,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _hourRow(int hour, List<DaySlot> slots) {
    return DragTarget<_SchedDrag>(
      onAcceptWithDetails: (details) => _onDrop(details.data, hour),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: highlight ? AppTheme.amber.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    if (slots.isEmpty)
                      Text(
                        highlight ? 'Drop to schedule' : '—',
                        style: TextStyle(
                          color: highlight
                              ? AppTheme.amber
                              : AppTheme.silver.withValues(alpha: 0.2),
                          fontSize: 12,
                        ),
                      ),
                    ...slots.map(
                      (s) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.title,
                            style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                        subtitle: Text(
                          '${s.timeLabel} · ${s.reason}',
                          style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                        ),
                        onTap: s.kind == DaySlotKind.task && s.entityId != null
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TaskDetailScreen(taskId: s.entityId!),
                                  ),
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
