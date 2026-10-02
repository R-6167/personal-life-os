import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/task_repository.dart';

/// Local notifications for reminders, bills, and overdue tasks (Android offline).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<int> syncFromDatabase() async {
    if (!_ready) await init();
    if (!enabled) {
      await cancelAll();
      return 0;
    }

    await cancelAll();
    var n = 0;
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 14));

    final reminders =
        await ExtendedRepository(AppDatabase.instance).listPendingReminders();
    for (final r in reminders) {
      final triggerMs = r['trigger_at'] as int?;
      if (triggerMs == null) continue;
      final when = DateTime.fromMillisecondsSinceEpoch(triggerMs);
      if (when.isBefore(now) || when.isAfter(horizon)) continue;
      await _schedule(
        id: _stableId('rem', r['id'] as String),
        title: '${r['title']}',
        body: 'Reminder from Personal Life OS',
        when: when,
      );
      n++;
    }

    final bills = await BillRepository(AppDatabase.instance).listOpenOccurrences();
    for (final o in bills) {
      final due = DateTime.fromMillisecondsSinceEpoch(o.dueAt);
      var when = DateTime(due.year, due.month, due.day, 9);
      if (when.isBefore(now)) {
        when = now.add(const Duration(minutes: 2));
      }
      if (when.isAfter(horizon)) continue;
      await _schedule(
        id: _stableId('bill', o.id),
        title: 'Bill: ${o.billName ?? 'Payment'}',
        body: o.expectedAmountMinor != null
            ? 'Due — ~${(o.expectedAmountMinor! / 100).toStringAsFixed(0)}'
            : 'Due soon',
        when: when,
      );
      n++;
    }

    final overdue = await TaskRepository(AppDatabase.instance).listOverdue();
    if (overdue.isNotEmpty) {
      await _schedule(
        id: 900001,
        title: '${overdue.length} overdue task${overdue.length == 1 ? '' : 's'}',
        body: overdue.take(3).map((t) => t.title).join(' · '),
        when: now.add(const Duration(minutes: 5)),
      );
      n++;
    }

    return n;
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final details = AndroidNotificationDetails(
      'plos_ops',
      'Personal Life OS',
      channelDescription: 'Reminders, bills, and task nudges',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _stableId(String prefix, String entityId) {
    return (prefix + entityId).hashCode & 0x7fffffff;
  }
}
