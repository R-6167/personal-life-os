import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/notification_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';

/// Reminder lifecycle: create → notify → snooze → complete / dismiss.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  List<Map<String, Object?>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _ext.listPendingReminders();
    if (!mounted) return;
    setState(() {
      _pending = rows;
      _loading = false;
    });
  }

  Future<void> _resyncNotifs() async {
    try {
      await NotificationService.instance.syncFromDatabase();
    } catch (_) {}
  }

  Future<void> _add() async {
    final title = TextEditingController();
    var hours = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('New reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: hours,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Remind in'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('In 15 minutes')),
                  DropdownMenuItem(value: 1, child: Text('In 1 hour')),
                  DropdownMenuItem(value: 3, child: Text('In 3 hours')),
                  DropdownMenuItem(value: 24, child: Text('Tomorrow')),
                  DropdownMenuItem(value: 72, child: Text('In 3 days')),
                ],
                onChanged: (v) => setLocal(() => hours = v ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final when = hours == 0
        ? DateTime.now().add(const Duration(minutes: 15))
        : DateTime.now().add(Duration(hours: hours));
    await _ext.addReminderAt(title: title.text.trim(), triggerAt: when);
    await _resyncNotifs();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder scheduled locally')),
      );
    }
  }

  Future<void> _snooze(String id, {int minutes = 15}) async {
    await _ext.snoozeReminder(id, minutes: minutes);
    await _resyncNotifs();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snoozed $minutes min')),
      );
    }
  }

  Future<void> _complete(String id) async {
    await _ext.completeReminder(id);
    await _resyncNotifs();
    await _load();
  }

  String _whenLabel(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = d.difference(now);
    if (diff.isNegative) return 'Due / past';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    return 'In ${diff.inDays}d · ${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Reminders'),
          actions: [
            IconButton(
              tooltip: 'New',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.alarm_add),
          label: const Text('Remind me'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _pending.isEmpty
                ? EmptyState(
                    icon: Icons.alarm_off_outlined,
                    title: 'No pending reminders',
                    subtitle: 'Create one — it stays on this device and notifies locally.',
                    actionLabel: 'New reminder',
                    onAction: _add,
                  )
                : RefreshIndicator(
                    color: AppTheme.amber,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _pending.length,
                      itemBuilder: (ctx, i) {
                        final r = _pending[i];
                        final id = r['id'] as String;
                        final title = '${r['title']}';
                        final trigger = r['trigger_at'] as int?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  _whenLabel(trigger),
                                  style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.45),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _snooze(id, minutes: 15),
                                      child: const Text('Snooze 15m'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _snooze(id, minutes: 60),
                                      child: const Text('Snooze 1h'),
                                    ),
                                    FilledButton(
                                      onPressed: () => _complete(id),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
