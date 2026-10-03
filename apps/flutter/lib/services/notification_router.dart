import 'package:flutter/material.dart';

import '../ui/screens/goal_detail_screen.dart';
import '../ui/screens/needs_attention_screen.dart';
import '../ui/screens/practical_life_screen.dart';
import '../ui/screens/project_detail_screen.dart';
import '../ui/screens/reminders_screen.dart';
import '../ui/screens/task_detail_screen.dart';
import 'notification_payload.dart';
import 'reminder_generator_service.dart';

/// Notify → Open: route a notification tap to the relevant action screen.
class NotificationRouter {
  NotificationRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> handle(String? rawPayload) async {
    final payload = NotificationPayload.tryParse(rawPayload);
    if (payload == null) return;

    if (payload.reminderId != null) {
      try {
        await ReminderGeneratorService().recordResult(
          reminderId: payload.reminderId!,
          result: 'OPENED',
        );
      } catch (_) {}
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (payload.type) {
      case NotificationPayload.task:
        nav.push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: payload.id)));
        break;
      case NotificationPayload.project:
        nav.push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: payload.id)));
        break;
      case NotificationPayload.goal:
        nav.push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: payload.id)));
        break;
      case NotificationPayload.bill:
      case NotificationPayload.billOcc:
      case NotificationPayload.subscription:
      case NotificationPayload.budget:
      case NotificationPayload.overdue:
      case NotificationPayload.habit:
      case NotificationPayload.routine:
        // Actionable hub for money / attention items
        nav.push(MaterialPageRoute(builder: (_) => const NeedsAttentionScreen()));
        break;
      case NotificationPayload.document:
      case NotificationPayload.practical:
        nav.push(MaterialPageRoute(builder: (_) => const PracticalLifeScreen()));
        break;
      case NotificationPayload.event:
      case NotificationPayload.reminder:
      default:
        nav.push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
        break;
    }
  }
}
