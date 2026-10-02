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
  List<Map<String, Object?>> _upcoming = [];
  List<Map<String, Object?>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final now = AppDatabase.nowMs();
    final end = now + const Duration(days: 14).inMilliseconds;
    final events = await db.query(
      'calendar_events',
      where: 'start_at >= ? AND start_at <= ? AND status != ?',
      whereArgs: [now - const Duration(hours: 12).inMilliseconds, end, 'CANCELLED'],
      orderBy: 'start_at ASC',
    );
    final rem = await _ext.listPendingReminders();
    setState(() {
      _upcoming = events;
      _reminders = rem;
      _loading = false;
    });
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    DateTime start = DateTime.now().add(const Duration(hours: 1));
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
    await _load();
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('Upcoming (14 days)', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_upcoming.isEmpty)
                    Text('No events scheduled', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ..._upcoming.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e['title']}', style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  _fmt(e['start_at'] as int),
                                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const Text('Reminders', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_reminders.isEmpty)
                    Text('No pending reminders', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
                  else
                    ..._reminders.map((r) => ListTile(
                          title: Text('${r['title']}', style: const TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            _fmt(r['trigger_at'] as int),
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        )),
                ],
              ),
      ),
    );
  }
}
