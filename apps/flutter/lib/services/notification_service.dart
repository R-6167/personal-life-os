import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/budget_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import 'notification_payload.dart';
import 'notification_router.dart';
import 'reminder_generator_service.dart';
import 'user_prefs.dart';

/// Local notification lifecycle:
/// Create → Schedule → Notify → Open / Snooze / Delete → Record result
///
/// Sound + vibration: Android channel is immutable, so channel id is bumped
/// when defaults change. Uses system default notification sound (ringtone-class
/// for alerts) plus explicit vibration patterns. Haptics for in-app actions
/// live in [FeedbackService].
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;

  /// Bumped to v3 so Android applies ringtone-style sound + vibration pattern.
  static const _channelId = 'ordin_alerts_v3';
  static const _channelName = 'Ordin Alerts';
  static const _channelDesc =
      'Tasks, bills, habits, and life reminders — sound & vibration';
  static const _iosCategory = 'ordin_actions';

  static const actionSnooze15 = 'SNOOZE_15';
  static const actionSnooze60 = 'SNOOZE_60';
  static const actionDelete = 'DELETE';

  /// Triple pulse for high-priority reminders (tasks / bills).
  static final Int64List _vibeHigh = Int64List.fromList([0, 300, 120, 300, 120, 300]);

  /// Double pulse for standard alerts (budget, soft reminders).
  static final Int64List _vibeNormal = Int64List.fromList([0, 200, 100, 200]);

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
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategory,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(actionSnooze15, 'Snooze 15m'),
            DarwinNotificationAction.plain(actionSnooze60, 'Snooze 1h'),
            DarwinNotificationAction.plain(
              actionDelete,
              'Delete',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}

    // Channel-level defaults: system default sound + vibration pattern.
    // (Channels are immutable; id bump forces re-create on install/update.)
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibeHigh,
        showBadge: true,
      ),
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final response = launch!.notificationResponse;
      if (response != null) {
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _handleResponse(response);
        });
      }
    }

    _ready = true;
  }

  void _onResponse(NotificationResponse response) {
    _handleResponse(response);
  }

  static Future<void> _handleResponse(NotificationResponse response) async {
    final action = response.actionId;
    final payload = response.payload;

    if (action == actionSnooze15 || action == actionSnooze60 || action == actionDelete) {
      await handleNotificationAction(
        actionId: action!,
        payload: payload,
        notificationId: response.id,
      );
      return;
    }

    await NotificationRouter.handle(payload);
  }

  static Future<void> handleNotificationAction({
    required String actionId,
    String? payload,
    int? notificationId,
  }) async {
    final parsed = NotificationPayload.tryParse(payload);
    final reminderId = parsed?.reminderId;

    try {
      if (notificationId != null) {
        await instance._plugin.cancel(notificationId);
      }
    } catch (_) {}

    if (reminderId == null || reminderId.isEmpty) {
      if (actionId == actionSnooze15 || actionId == actionSnooze60) {
        final mins = actionId == actionSnooze15 ? 15 : 60;
        try {
          await instance._schedule(
            id: notificationId ?? instance._stableId('snooze', payload ?? 'x'),
            title: 'Snoozed reminder',
            body: 'Back in ${mins}m',
            when: DateTime.now().add(Duration(minutes: mins)),
            payload: payload,
          );
        } catch (_) {}
      }
      return;
    }

    try {
      await AppDatabase.instance.database;
      final ext = ExtendedRepository(AppDatabase.instance);

      if (actionId == actionSnooze15 || actionId == actionSnooze60) {
        final mins = actionId == actionSnooze15 ? 15 : 60;
        await ext.snoozeReminder(reminderId, minutes: mins);
        try {
          await ReminderGeneratorService().recordResult(
            reminderId: reminderId,
            result: 'SNOOZED',
            snoozeMinutes: mins,
          );
        } catch (_) {}
        try {
          await instance.syncFromDatabase();
        } catch (_) {}
        return;
      }

      if (actionId == actionDelete) {
        await _cancelReminder(reminderId);
        try {
          await ReminderGeneratorService().recordResult(
            reminderId: reminderId,
            result: 'DISMISSED',
          );
        } catch (_) {}
        try {
          await instance.syncFromDatabase();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> _cancelReminder(String id) async {
    final now = AppDatabase.nowMs();
    await (await AppDatabase.instance.database).update(
      'reminders',
      {'status': 'CANCELLED', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> cancelId(int id) => _plugin.cancel(id);

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
        high: true,
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
        body: '$cat · $spent / $limit',
        when: when,
        high: exceeded,
        payload: payload.encode(),
      );
      n++;
    }
    return n;
  }

  Future<List<BudgetStatus>> checkBudgetsNow() async {
    final hit = await BudgetRepository(AppDatabase.instance).alerts();
    final alerts = hit.where((s) => s.level != BudgetAlertLevel.ok).toList();
    if (alerts.isNotEmpty) await notifyBudgetAlerts();
    return hit;
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
    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        actionSnooze15,
        'Snooze 15m',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        actionSnooze60,
        'Snooze 1h',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        actionDelete,
        'Delete',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    // Prefer exact alarm when permitted; fall back to inexact.
    AndroidScheduleMode mode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidPlugin?.canScheduleExactNotifications();
      if (canExact == true) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}

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
          actions: actions,
          // Reminder category + ringtone usage → system default alert sound.
          category: AndroidNotificationCategory.reminder,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          playSound: true,
          enableVibration: true,
          vibrationPattern: high ? _vibeHigh : _vibeNormal,
          ticker: title,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _iosCategory,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          interruptionLevel: high
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int _stableId(String prefix, String key) {
    var h = prefix.hashCode ^ key.hashCode;
    h = h & 0x7fffffff;
    if (h == 0) h = 1;
    return h;
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService._handleResponse(response);
}
