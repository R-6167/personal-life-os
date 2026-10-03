/// Canonical recurrence model for Ordin.
///
/// Pipeline:
///   RecurrenceRule → OccurrenceGenerator → Occurrence → (domain activity)
///
/// Reused by tasks, habits, routines, bills, subscriptions, reminders.
library;

enum RecurrenceFrequency {
  once,
  daily,
  weekly,
  monthly,
  yearly;

  static RecurrenceFrequency parse(String? raw) {
    switch ((raw ?? 'DAILY').toUpperCase().trim()) {
      case 'ONCE':
      case 'ONE_TIME':
      case 'NONE':
        return RecurrenceFrequency.once;
      case 'WEEKLY':
        return RecurrenceFrequency.weekly;
      case 'MONTHLY':
        return RecurrenceFrequency.monthly;
      case 'YEARLY':
      case 'ANNUAL':
        return RecurrenceFrequency.yearly;
      case 'DAILY':
      default:
        return RecurrenceFrequency.daily;
    }
  }

  String get wire {
    switch (this) {
      case RecurrenceFrequency.once:
        return 'ONCE';
      case RecurrenceFrequency.daily:
        return 'DAILY';
      case RecurrenceFrequency.weekly:
        return 'WEEKLY';
      case RecurrenceFrequency.monthly:
        return 'MONTHLY';
      case RecurrenceFrequency.yearly:
        return 'YEARLY';
    }
  }
}

/// Immutable rule. All dates are local civil dates (time-of-day preserved from dtStart).
class RecurrenceRule {
  /// Anchor / first occurrence basis.
  final DateTime dtStart;

  final RecurrenceFrequency frequency;

  /// Every N periods (N ≥ 1). Weekly: every N weeks; monthly: every N months.
  final int interval;

  /// Inclusive end date (local day). Null = no end by date.
  final DateTime? until;

  /// Max number of occurrences including the first. Null = unbounded (generator still limited).
  final int? count;

  /// Weekdays: DateTime.monday=1 … DateTime.sunday=7. Empty = use dtStart weekday only for weekly.
  final List<int> byWeekDays;

  /// Days of month 1–31. Use -1 for last day of month. Empty = use dtStart.day.
  final List<int> byMonthDays;

  const RecurrenceRule({
    required this.dtStart,
    this.frequency = RecurrenceFrequency.daily,
    this.interval = 1,
    this.until,
    this.count,
    this.byWeekDays = const [],
    this.byMonthDays = const [],
  });

  int get safeInterval => interval < 1 ? 1 : interval;

  /// Parse common DB shapes (task_recurrences, habit_schedules, bills).
  factory RecurrenceRule.fromLegacy({
    required String frequency,
    int interval = 1,
    DateTime? dtStart,
    DateTime? until,
    int? count,
    String? daysOfWeekCsv,
    List<int>? daysOfWeek,
    int? monthDay,
  }) {
    final start = dtStart ?? DateTime.now();
    final days = <int>[];
    if (daysOfWeek != null) {
      days.addAll(daysOfWeek.where((d) => d >= 1 && d <= 7));
    } else if (daysOfWeekCsv != null && daysOfWeekCsv.trim().isNotEmpty) {
      for (final p in daysOfWeekCsv.split(RegExp(r'[,;\s]+'))) {
        final n = int.tryParse(p.trim());
        if (n != null && n >= 1 && n <= 7) days.add(n);
        // Accept Mon/Tue style lightly
        final u = p.trim().toUpperCase();
        const map = {
          'MON': 1,
          'TUE': 2,
          'WED': 3,
          'THU': 4,
          'FRI': 5,
          'SAT': 6,
          'SUN': 7,
        };
        if (map.containsKey(u.take(3))) days.add(map[u.take(3)]!);
      }
    }
    final monthDays = <int>[];
    if (monthDay != null) monthDays.add(monthDay);
    return RecurrenceRule(
      dtStart: DateTime(start.year, start.month, start.day, start.hour, start.minute),
      frequency: RecurrenceFrequency.parse(frequency),
      interval: interval < 1 ? 1 : interval,
      until: until == null
          ? null
          : DateTime(until.year, until.month, until.day, 23, 59, 59, 999),
      count: count,
      byWeekDays: days.toSet().toList()..sort(),
      byMonthDays: monthDays,
    );
  }

  OccurrenceGenerator generator() => OccurrenceGenerator(this);
}

/// One concrete instance produced by the generator.
class Occurrence {
  final DateTime start;
  final int index; // 0-based from dtStart series

  const Occurrence({required this.start, required this.index});

  int get startMs => start.millisecondsSinceEpoch;

  DateTime get day => DateTime(start.year, start.month, start.day);
}

/// Expands a [RecurrenceRule] into concrete local datetimes.
class OccurrenceGenerator {
  OccurrenceGenerator(this.rule);

  final RecurrenceRule rule;

  static const _maxScanDays = 366 * 6; // safety for open-ended walks

  /// Occurrences with start > [after] (exclusive), optional [before] exclusive, max [limit].
  List<Occurrence> generate({
    DateTime? after,
    DateTime? before,
    int limit = 64,
  }) {
    final out = <Occurrence>[];
    final start = rule.dtStart;
    final afterEx = after ?? start.subtract(const Duration(milliseconds: 1));

    if (rule.frequency == RecurrenceFrequency.once) {
      if (start.isAfter(afterEx) && (before == null || start.isBefore(before))) {
        if (_withinUntil(start) && _withinCount(0)) {
          out.add(Occurrence(start: start, index: 0));
        }
      }
      return out;
    }

    var index = 0;
    // Seed cursor just before first possible
    DateTime cursor = DateTime(start.year, start.month, start.day);

    // Fast-forward roughly for daily/weekly to avoid long loops when after >> start
    if (after != null && after.isAfter(start)) {
      cursor = DateTime(after.year, after.month, after.day);
    }

    for (var scan = 0; scan < _maxScanDays && out.length < limit; scan++) {
      final candidates = _candidatesOnOrAfter(cursor, indexHint: index);
      if (candidates.isEmpty) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      for (final c in candidates) {
        if (!c.isAfter(afterEx)) continue;
        if (before != null && !c.isBefore(before)) return out;
        if (!_withinUntil(c)) return out;
        if (!_withinCount(index)) return out;
        // Interval filter for weekly/monthly/yearly series membership
        if (!_matchesIntervalSeries(c, index)) {
          // still advance index only for true series members — handled below
          continue;
        }
        out.add(Occurrence(start: _withTime(c), index: index));
        index++;
        if (out.length >= limit) return out;
        if (!_withinCount(index)) return out;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  /// Next occurrence strictly after [after], or null if none.
  DateTime? nextAfter(DateTime after) {
    final list = generate(after: after, limit: 1);
    return list.isEmpty ? null : list.first.start;
  }

  /// Next occurrence on or after [from] (inclusive of same calendar day if still valid).
  DateTime? nextOnOrAfter(DateTime from) {
    final dayStart = DateTime(from.year, from.month, from.day).subtract(const Duration(milliseconds: 1));
    return nextAfter(dayStart);
  }

  bool occursOn(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));
    return generate(after: d0.subtract(const Duration(milliseconds: 1)), before: d1, limit: 1)
        .isNotEmpty;
  }

  // —— internals ——

  bool _withinUntil(DateTime t) {
    final u = rule.until;
    if (u == null) return true;
    return !t.isAfter(u);
  }

  bool _withinCount(int index) {
    final c = rule.count;
    if (c == null) return true;
    return index < c;
  }

  DateTime _withTime(DateTime day) {
    final s = rule.dtStart;
    return DateTime(day.year, day.month, day.day, s.hour, s.minute, s.second);
  }

  /// Days that could fire on [cursor] calendar day (0 or 1 for most rules).
  List<DateTime> _candidatesOnOrAfter(DateTime cursor, {required int indexHint}) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    switch (rule.frequency) {
      case RecurrenceFrequency.once:
        final s = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
        return day == s ? [day] : [];
      case RecurrenceFrequency.daily:
        if (_dailyMatches(day)) return [day];
        return [];
      case RecurrenceFrequency.weekly:
        if (_weeklyMatches(day)) return [day];
        return [];
      case RecurrenceFrequency.monthly:
        if (_monthlyMatches(day)) return [day];
        return [];
      case RecurrenceFrequency.yearly:
        if (_yearlyMatches(day)) return [day];
        return [];
    }
  }

  bool _dailyMatches(DateTime day) {
    final start = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
    if (day.isBefore(start)) return false;
    final days = day.difference(start).inDays;
    return days % rule.safeInterval == 0;
  }

  bool _weeklyMatches(DateTime day) {
    final start = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
    if (day.isBefore(start)) return false;

    final weekDays = rule.byWeekDays.isEmpty ? [rule.dtStart.weekday] : rule.byWeekDays;
    if (!weekDays.contains(day.weekday)) return false;

    // Interval in weeks from the Monday of dtStart week
    final startMon = _mondayOf(start);
    final dayMon = _mondayOf(day);
    final weeks = dayMon.difference(startMon).inDays ~/ 7;
    if (weeks < 0) return false;
    return weeks % rule.safeInterval == 0;
  }

  bool _monthlyMatches(DateTime day) {
    final start = rule.dtStart;
    final startMonthIndex = start.year * 12 + (start.month - 1);
    final dayMonthIndex = day.year * 12 + (day.month - 1);
    if (dayMonthIndex < startMonthIndex) return false;
    final months = dayMonthIndex - startMonthIndex;
    if (months % rule.safeInterval != 0) return false;

    final targets = rule.byMonthDays.isEmpty ? [start.day] : rule.byMonthDays;
    for (final raw in targets) {
      final dom = _resolveMonthDay(day.year, day.month, raw);
      if (day.day == dom) return true;
    }
    return false;
  }

  bool _yearlyMatches(DateTime day) {
    final start = rule.dtStart;
    if (day.year < start.year) return false;
    if ((day.year - start.year) % rule.safeInterval != 0) return false;

    final targets = rule.byMonthDays.isEmpty ? [start.day] : rule.byMonthDays;
    if (day.month != start.month) return false;
    for (final raw in targets) {
      final dom = _resolveMonthDay(day.year, day.month, raw);
      if (day.day == dom) return true;
    }
    return false;
  }

  /// Series index filter — already encoded in daily/weekly/monthly matchers.
  bool _matchesIntervalSeries(DateTime c, int index) => true;

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// [raw] 1–31 or -1 (last day). Clamps to real last day of month (no day-28-only hack).
  static int _resolveMonthDay(int year, int month, int raw) {
    final last = DateTime(year, month + 1, 0).day;
    if (raw == -1) return last;
    if (raw < 1) return 1;
    return raw > last ? last : raw;
  }

  /// Add [months] to [y]/[m] preserving intent for day-of-month via clamp.
  static DateTime addMonthsClamped(DateTime from, int months, {int? dayOfMonth}) {
    final targetMonthIndex = from.year * 12 + (from.month - 1) + months;
    final y = targetMonthIndex ~/ 12;
    final m = targetMonthIndex % 12 + 1;
    final dom = _resolveMonthDay(y, m, dayOfMonth ?? from.day);
    return DateTime(y, m, dom, from.hour, from.minute, from.second);
  }
}

/// Backward-compatible façade used by older call sites.
class RecurrenceEngine {
  /// Next occurrence strictly after [fromMs].
  /// ONCE returns [fromMs] so callers can treat as terminal.
  static int nextAfter(
    int fromMs, {
    required String frequency,
    int interval = 1,
    List<int>? daysOfWeek,
    DateTime? dtStart,
    DateTime? until,
    int? count,
    int? monthDay,
  }) {
    final f = RecurrenceFrequency.parse(frequency);
    if (f == RecurrenceFrequency.once) return fromMs;

    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final rule = RecurrenceRule.fromLegacy(
      frequency: frequency,
      interval: interval,
      dtStart: dtStart ?? from,
      until: until,
      count: count,
      daysOfWeek: daysOfWeek,
      monthDay: monthDay,
    );
    final next = rule.generator().nextAfter(from);
    return next?.millisecondsSinceEpoch ?? fromMs;
  }

  static bool isScheduledDay(
    int dayMs, {
    required String frequency,
    List<int>? daysOfWeek,
    int interval = 1,
    DateTime? dtStart,
  }) {
    final day = DateTime.fromMillisecondsSinceEpoch(dayMs);
    final rule = RecurrenceRule.fromLegacy(
      frequency: frequency,
      interval: interval,
      dtStart: dtStart ?? day,
      daysOfWeek: daysOfWeek,
    );
    return rule.generator().occursOn(day);
  }

  /// Expand the next [limit] occurrences after [fromMs].
  static List<int> expandAfter(
    int fromMs, {
    required String frequency,
    int interval = 1,
    List<int>? daysOfWeek,
    DateTime? dtStart,
    DateTime? until,
    int limit = 12,
  }) {
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final rule = RecurrenceRule.fromLegacy(
      frequency: frequency,
      interval: interval,
      dtStart: dtStart ?? from,
      until: until,
      daysOfWeek: daysOfWeek,
    );
    return rule
        .generator()
        .generate(after: from, limit: limit)
        .map((o) => o.startMs)
        .toList();
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
