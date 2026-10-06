import 'package:flutter/services.dart';

/// In-app haptics for actions that change life state.
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
