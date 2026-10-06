import 'package:flutter/services.dart';

/// In-app haptics for actions that change life state.
///
/// Pair with [NotificationService] for out-of-app sound/vibration on reminders.
/// - selection: light UI taps
/// - light: dismiss / soft cancel
/// - success: complete task, approve assistant action
/// - heavy: important confirmations
/// - warn: delete / destructive
class FeedbackService {
  FeedbackService._();
  static final instance = FeedbackService._();

  bool enabled = true;

  void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  void success() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  void warn() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
