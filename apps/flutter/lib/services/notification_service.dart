import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/budget_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../domain/enums.dart';
import 'notification_payload.dart';
import 'notification_router.dart';
import 'reminder_generator_service.dart';
import 'user_prefs.dart';

/// Local notification lifecycle:
/// Create → Schedule → Notify → Open → Snooze/Complete → Record result
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;

  static const _channelId = 'ordin_life';
  static const _channelName = 'Ordin Life';
  static const _channelDesc = 'Tasks, bills, habits, and life reminders';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
      } catch (_) {}
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    // Cold start: user opened app from a notification
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final p = launch!.notificationResponse?.payload;
      if (p != null) {
        // Defer until first frame / navigator ready
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          NotificationRouter.handle(p);
        });
      }
    }

    _ready = true;
  }

  void _onResponse(NotificationResponse response) {
    NotificationRouter.handle(response.payload);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Full pipeline: generate entity reminders → schedule OS notifications.
  Future<int> syncFromDatabase() async {
    if (!_ready) await init();
    if (!enabled) {
      await cancelAll();
      return 0;
    }

    try {
      await ReminderGeneratorService().generateAll();
    } catch (_) {}

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
      if (when.isBefore(now.subtract(const Duration(minutes: 1)))) continue;
      if (when.isAfter(horizon)) continue;

      final sourceType = '${r['source_type'] ?? NotificationPayload.reminder}';
      final sourceId = '${r['source_id'] ?? r['id']}';
      final remId = '${r['id']}';
      final payload = NotificationPayload(
        type: sourceType.isEmpty ? NotificationPayload.reminder : sourceType,
        id: sourceId,
        reminderId: remId,
      );

      final body = '${r['message'] ?? 'Open Ordin to act'}'
          .replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');

      await _schedule(
        id: _stableId('rem', remId),
        title: '${r['title']}',
        body: body,
        when: when,
        payload: payload.encode(),
      );
      n++;
    }

    n += await notifyBudgetAlerts(delay: const Duration(seconds: 2));
    return n;
  }

  Future<int> notifyBudgetAlerts({Duration delay = const Duration(seconds: 2)}) async {
    if (!_ready) await init();
    if (!enabled) return 0;
    final alerts = await BudgetRepository(AppDatabase.instance).alerts();
    if (alerts.isEmpty) return 0;
    var n = 0;
    final when = DateTime.now().add(delay);
    for (final b in alerts) {
      final spent = (b.spentMinor / 100).toStringAsFixed(0);
      final limit = (b.limitMinor / 100).toStringAsFixed(0);
      final cat = b.categoryName ?? b.scopeLabel;
      final exceeded = b.level == BudgetAlertLevel.exceeded;
      final payload = NotificationPayload(
        type: NotificationPayload.budget,
        id: b.id,
      );
      await _schedule(
        id: _stableId('bud', b.id),
        title: exceeded ? 'Budget exceeded: ${b.name}' : 'Budget warning: ${b.name}',
        body: '$cat · $spent / $limit ${UserPrefs.instance.currency}'
            '${exceeded ? ' — over limit' : ' — near limit'}',
        when: when,
        high: exceeded,
        payload: payload.encode(),
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
    bool high = false,
    String? payload,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: high ? Importance.max : Importance.high,
          priority: high ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int _stableId(String prefix, String key) {
    // 31-bit positive int from string
    var h = prefix.hashCode ^ key.hashCode;
    h = h & 0x7fffffff;
    if (h == 0) h = 1;
    return h;
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background isolate — full navigation happens on next foreground via payload.
}
