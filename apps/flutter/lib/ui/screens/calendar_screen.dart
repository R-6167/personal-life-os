import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

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
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
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
                  setLocal(() {
                    start = DateTime(d.year, d.month, d.day, t?.hour ?? start.hour, t?.minute ?? start.minute);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ownerId = await AppDatabase.instance.requireOwnerId();
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = startMs + const Duration(hours: 1).inMilliseconds;
    await AppDatabase.instance.txn((txn) async {
      final id = AppDatabase.newId();
      await txn.insert('calendar_events', {
        'id': id,
        'owner_id': ownerId,
        'title': title.text.trim(),
        'start_at': startMs,
        'end_at': endMs,
        'status': 'SCHEDULED',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'EVENT_CREATED',
        'entity_type': 'CALENDAR_EVENT',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': 'USER',
      });
    });
    setState(() {
      _selected = DateTime(start.year, start.month, start.day);
      _month = DateTime(start.year, start.month);
    });
    await _load();
  }

  Future<void> _cancelEvent(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'calendar_events',
      {'status': 'CANCELLED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
  }

  Future<void> _snoozeReminder(String id) async {
    await _ext.snoozeReminder(id, minutes: 15);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snoozed 15m')));
    }
  }

  Future<void> _completeReminder(String id) async {
    await _ext.completeReminder(id);
    await _load();
  }

  Future<void> _deleteReminder(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    await _load();
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${_fmt(ms)}';
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () async {
                setState(() => _month = DateTime(_month.year, _month.month - 1));
                await _load();
              },
              icon: const Icon(Icons.chevron_left, color: AppTheme.silver),
            ),
            Expanded(
              child: Text(
                '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: () async {
                setState(() => _month = DateTime(_month.year, _month.month + 1));
                await _load();
              },
              icon: const Icon(Icons.chevron_right, color: AppTheme.silver),
            ),
          ],
        ),
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 11)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: List.generate(7, (c) {
              final i = r * 7 + c;
              final dayNum = i - lead + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }
              final day = DateTime(_month.year, _month.month, dayNum);
              final selected = day == _selected;
              final has = _eventsOn(day).isNotEmpty;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = day),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.amber.withValues(alpha: 0.25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: selected ? Border.all(color: AppTheme.amber) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: selected ? AppTheme.amber : AppTheme.silver,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
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
            }),
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
        appBar: AppBar(title: const Text('Calendar & plans')),
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
                    Text('No events this day', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ...dayEvents.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: ListTile(
                              title: Text('${e['title']}', style: const TextStyle(color: AppTheme.silver)),
                              subtitle: Text(_fmt(e['start_at'] as int),
                                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                tooltip: 'Cancel event',
                                onPressed: () => _cancelEvent(e['id'] as String),
                              ),
                            ),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const Text('Reminders', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_reminders.isEmpty)
                    Text('No pending reminders', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ..._reminders.map((r) {
                      final source = r['source_type'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: ListTile(
                            title: Text('${r['title']}', style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(
                              [
                                _fmtDate(r['trigger_at'] as int),
                                if (source != null) source,
                              ].join(' · '),
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.snooze, color: AppTheme.amber, size: 20),
                                  tooltip: 'Snooze 15m',
                                  onPressed: () => _snoozeReminder(r['id'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: AppTheme.amber, size: 20),
                                  tooltip: 'Done',
                                  onPressed: () => _completeReminder(r['id'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete',
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
