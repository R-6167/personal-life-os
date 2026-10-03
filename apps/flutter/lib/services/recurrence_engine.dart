/// Shared recurrence math for bills, habits, tasks (offline, deterministic).
class RecurrenceEngine {
  /// Next occurrence after [fromMs] for a simple frequency rule.
  /// Returns [fromMs] for ONCE / ONE_TIME / NONE (caller should not schedule again).
  static int nextAfter(
    int fromMs, {
    required String frequency,
    int interval = 1,
    List<int>? daysOfWeek, // 1=Mon … 7=Sun
  }) {
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final f = frequency.toUpperCase();
    switch (f) {
      case 'ONCE':
      case 'ONE_TIME':
      case 'NONE':
        return fromMs;
      case 'DAILY':
        return from.add(Duration(days: interval)).millisecondsSinceEpoch;
      case 'WEEKLY':
        if (daysOfWeek == null || daysOfWeek.isEmpty) {
          return from.add(Duration(days: 7 * interval)).millisecondsSinceEpoch;
        }
        var cursor = from.add(const Duration(days: 1));
        for (var i = 0; i < 14 * interval; i++) {
          final wd = cursor.weekday;
          if (daysOfWeek.contains(wd)) {
            return DateTime(cursor.year, cursor.month, cursor.day).millisecondsSinceEpoch;
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        return from.add(Duration(days: 7 * interval)).millisecondsSinceEpoch;
      case 'YEARLY':
        return DateTime(from.year + interval, from.month, from.day.clamp(1, 28))
            .millisecondsSinceEpoch;
      case 'MONTHLY':
      default:
        var month = from.month + interval;
        var year = from.year;
        while (month > 12) {
          month -= 12;
          year++;
        }
        final day = from.day.clamp(1, 28);
        return DateTime(year, month, day).millisecondsSinceEpoch;
    }
  }

  static bool isScheduledDay(
    int dayMs, {
    required String frequency,
    List<int>? daysOfWeek,
  }) {
    final d = DateTime.fromMillisecondsSinceEpoch(dayMs);
    final f = frequency.toUpperCase();
    if (f == 'ONCE' || f == 'ONE_TIME' || f == 'NONE') return true;
    if (f == 'DAILY') return true;
    if (f == 'WEEKLY') {
      if (daysOfWeek == null || daysOfWeek.isEmpty) return true;
      return daysOfWeek.contains(d.weekday);
    }
    if (f == 'MONTHLY') return d.day == 1 || daysOfWeek == null;
    return true;
  }
}
