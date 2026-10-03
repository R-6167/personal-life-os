import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'schedule_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<Map<String, Object?>> _monthEvents = [];
  List<Map<String, Object?>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1);
    final events = await db.query(
      'calendar_events',
      where: 'start_at >= ? AND start_at < ? AND status != ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        'CANCELLED',
      ],
      orderBy: 'start_at ASC',
    );
    final rem = await _ext.listPendingReminders();
    if (!mounted) return;
    setState(() {
      _monthEvents = events;
      _reminders = rem;
      _loading = false;
    });
  }

  List<Map<String, Object?>> _eventsOn(DateTime day) {
    final s = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final e = s + const Duration(days: 1).inMilliseconds;
    return _monthEvents.where((ev) {
      final t = ev['start_at'] as int;
      return t >= s && t < e;
    }).toList();
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    DateTime start = DateTime(_selected.year, _selected.month, _selected.day, DateTime.now().hour + 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('New event', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver),
                ),
                trailing: const Icon(Icons.edit_calendar, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(start),
                  );
                  if (t == null) return;
                  setLocal(() {
                    start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final ownerId = await AppDatabase.instance.requireOwnerId();
    final now = AppDatabase.nowMs();
    final db = await AppDatabase.instance.database;
    await db.insert('calendar_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title.text.trim(),
      'start_at': start.millisecondsSinceEpoch,
      'end_at': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'created_at': now,
      'updated_at': now,
    });
    await _load();
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _snoozeReminder(String id) async {
    await _ext.snoozeReminder(id, minutes: 15);
    await _load();
  }

  Future<void> _completeReminder(String id) async {
    await _ext.completeReminder(id);
    await _load();
  }

  Future<void> _deleteReminder(String id) async {
    await _ext.deleteReminder(id);
    await _load();
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = first.weekday % 7; // Sun=0
    final cells = <Widget>[];
    for (final w in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) {
      cells.add(Center(
          child: Text(w, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11))));
    }
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_month.year, _month.month, d);
      final selected =
          day.year == _selected.year && day.month == _selected.month && day.day == _selected.day;
      final has = _eventsOn(day).isNotEmpty;
      cells.add(
        InkWell(
          onTap: () => setState(() => _selected = day),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppTheme.amber.withValues(alpha: 0.25) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$d',
                    style: TextStyle(
                        color: AppTheme.silver,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                if (has)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(color: AppTheme.amber, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _month = DateTime(_month.year, _month.month - 1));
                _load();
              },
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _month = DateTime(_month.year, _month.month + 1));
                _load();
              },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          children: cells,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _eventsOn(_selected);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Calendar & plans'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScheduleScreen(initialDay: _selected),
                  ),
                );
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addEvent,
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  GlassCard(child: _monthGrid()),
                  const SizedBox(height: 16),
                  Text(
                    'Selected ${_selected.year}-${_selected.month.toString().padLeft(2, '0')}-${_selected.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (dayEvents.isEmpty)
                    Text('No events this day',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ...dayEvents.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: ListTile(
                              title: Text('${e['title']}',
                                  style: const TextStyle(color: AppTheme.silver)),
                              subtitle: Text(_fmtDate(e['start_at'] as int),
                                  style: TextStyle(
                                      color: AppTheme.silver.withValues(alpha: 0.4),
                                      fontSize: 12)),
                            ),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const Text('Reminders',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_reminders.isEmpty)
                    Text('No pending reminders',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ..._reminders.map((r) {
                      final source = r['source_type'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: ListTile(
                            title: Text('${r['title']}',
                                style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(
                              [
                                _fmtDate(r['trigger_at'] as int),
                                if (source != null) source,
                              ].join(' · '),
                              style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.snooze, color: AppTheme.amber, size: 20),
                                  onPressed: () => _snoozeReminder(r['id'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: AppTheme.amber, size: 20),
                                  onPressed: () => _completeReminder(r['id'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteReminder(r['id'] as String),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
