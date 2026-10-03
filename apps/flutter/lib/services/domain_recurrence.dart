/// Universal recurrence helpers for every domain.
///
/// Rule: no domain invents its own recurrence math.
/// All schedules go through:
///   schedule row / legacy fields
///        ↓
///   RecurrenceRule.fromScheduleMap / fromLegacy
///        ↓
///   OccurrenceGenerator
///        ↓
///   Occurrence (then domain writes its own occurrence row)
library;

import 'recurrence_engine.dart';

/// Shared schedule-row → rule mapping used by tasks, habits, routines,
/// bills, subscriptions, and practical items.
class DomainRecurrence {
  DomainRecurrence._();

  /// Civil day key in ms (local midnight) — same convention as HabitRepository.dayKey.
  static int dayKeyMs([DateTime? day]) {
    final d = day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  static DateTime dayOf(int dayKeyMs) =>
      DateTime.fromMillisecondsSinceEpoch(dayKeyMs);

  /// Build a rule from a schedule / recurrence table row.
  ///
  /// Accepted keys (any subset):
  ///   frequency | freq, interval | interval_n,
  ///   days_of_week, by_month_days | month_day,
  ///   start_date | dt_start | next_due_at | next_renewal_at,
  ///   until_at | end_at, count
  static RecurrenceRule ruleFromScheduleMap(
    Map<String, Object?> row, {
    DateTime? fallbackStart,
  }) {
    final freq = '${row['frequency'] ?? row['freq'] ?? 'DAILY'}';
    final interval = (row['interval'] as int?) ??
        (row['interval_n'] as int?) ??
        1;
    final startMs = row['start_date'] as int? ??
        row['dt_start'] as int? ??
        row['next_due_at'] as int? ??
        row['next_renewal_at'] as int?;
    final untilMs = row['until_at'] as int? ?? row['end_at'] as int?;
    final count = row['count'] as int?;
    final daysCsv = row['days_of_week'] as String?;
    final monthCsv = row['by_month_days'] as String?;
    int? monthDay = row['month_day'] as int?;
    if (monthDay == null && monthCsv != null && monthCsv.trim().isNotEmpty) {
      monthDay = int.tryParse(monthCsv.split(',').first.trim());
    }

    return RecurrenceRule.fromLegacy(
      frequency: freq,
      interval: interval,
      dtStart: startMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : (fallbackStart ?? DateTime.now()),
      until: untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs),
      count: count,
      daysOfWeekCsv: daysCsv,
      monthDay: monthDay,
    );
  }

  /// Whether [day] is an occurrence of [rule].
  static bool occursOn(RecurrenceRule rule, DateTime day) =>
      rule.generator().occursOn(day);

  /// Next occurrence strictly after [from] (ms since epoch).
  static int? nextAfterMs(RecurrenceRule rule, int fromMs) {
    final next = rule.generator().nextAfter(
      DateTime.fromMillisecondsSinceEpoch(fromMs),
    );
    return next?.millisecondsSinceEpoch;
  }

  /// Next occurrence on or after civil [day].
  static DateTime? nextOnOrAfter(RecurrenceRule rule, DateTime day) =>
      rule.generator().nextOnOrAfter(day);

  /// Expand up to [limit] starts after [fromMs].
  static List<int> expandAfterMs(
    RecurrenceRule rule,
    int fromMs, {
    int limit = 12,
  }) {
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    return rule
        .generator()
        .generate(after: from, limit: limit)
        .map((o) => o.startMs)
        .toList();
  }

  /// Convenience for domains that still pass raw frequency strings
  /// (bills, subscriptions). Prefer [ruleFromScheduleMap] when a row exists.
  static int nextDueFromLegacy({
    required int fromMs,
    required String frequency,
    int interval = 1,
    List<int>? daysOfWeek,
    DateTime? dtStart,
    DateTime? until,
    int? count,
    int? monthDay,
  }) {
    return RecurrenceEngine.nextAfter(
      fromMs,
      frequency: frequency,
      interval: interval,
      daysOfWeek: daysOfWeek,
      dtStart: dtStart,
      until: until,
      count: count,
      monthDay: monthDay,
    );
  }

  static bool isRecurringFrequency(String? frequency) {
    final f = RecurrenceFrequency.parse(frequency);
    return f != RecurrenceFrequency.once;
  }
}
