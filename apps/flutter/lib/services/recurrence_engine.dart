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

/// Immutable rule. Civil dates; time-of-day preserved from [dtStart].
class RecurrenceRule {
  final DateTime dtStart;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? until;
  final int? count;

  /// DateTime.monday=1 … sunday=7.
  final List<int> byWeekDays;

  /// 1–31 or -1 (last day of month).
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
        final token = p.trim();
        if (token.isEmpty) continue;
        final n = int.tryParse(token);
        if (n != null && n >= 1 && n <= 7) {
          days.add(n);
          continue;
        }
        final u = token.toUpperCase();
        const map = {
          'MON': 1,
          'TUE': 2,
          'WED': 3,
          'THU': 4,
          'FRI': 5,
          'SAT': 6,
          'SUN': 7,
        };
        final key = u.length >= 3 ? u.substring(0, 3) : u;
        final wd = map[key];
        if (wd != null) days.add(wd);
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

class Occurrence {
  final DateTime start;
  final int index;

  const Occurrence({required this.start, required this.index});

  int get startMs => start.millisecondsSinceEpoch;

  DateTime get day => DateTime(start.year, start.month, start.day);
}

class OccurrenceGenerator {
  OccurrenceGenerator(this.rule);

  final RecurrenceRule rule;

  static const _maxScanDays = 366 * 6;

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
    var cursor = DateTime(start.year, start.month, start.day);
    if (after != null && after.isAfter(start)) {
      cursor = DateTime(after.year, after.month, after.day);
    }

    // When fast-forwarding, approximate index so count limits stay honest.
    if (cursor.isAfter(DateTime(start.year, start.month, start.day))) {
      index = _estimateIndexBefore(cursor);
    }

    for (var scan = 0; scan < _maxScanDays && out.length < limit; scan++) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      if (_matches(day)) {
        final at = _withTime(day);
        if (at.isAfter(afterEx)) {
          if (before != null && !at.isBefore(before)) return out;
          if (!_withinUntil(at)) return out;
          if (!_withinCount(index)) return out;
          out.add(Occurrence(start: at, index: index));
          index++;
          if (out.length >= limit) return out;
        } else {
          index++;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  DateTime? nextAfter(DateTime after) {
    final list = generate(after: after, limit: 1);
    return list.isEmpty ? null : list.first.start;
  }

  DateTime? nextOnOrAfter(DateTime from) {
    final dayStart =
        DateTime(from.year, from.month, from.day).subtract(const Duration(milliseconds: 1));
    return nextAfter(dayStart);
  }

  bool occursOn(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));
    return generate(
          after: d0.subtract(const Duration(milliseconds: 1)),
          before: d1,
          limit: 1,
        ).isNotEmpty;
  }

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

  int _estimateIndexBefore(DateTime cursor) {
    // Best-effort for count tracking when starting mid-series.
    final start = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
    if (!cursor.isAfter(start)) return 0;
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        return cursor.difference(start).inDays ~/ rule.safeInterval;
      case RecurrenceFrequency.weekly:
        final weeks = _mondayOf(cursor).difference(_mondayOf(start)).inDays ~/ 7;
        final daysPerWeek = (rule.byWeekDays.isEmpty ? 1 : rule.byWeekDays.length);
        return (weeks ~/ rule.safeInterval) * daysPerWeek;
      case RecurrenceFrequency.monthly:
        final sm = start.year * 12 + (start.month - 1);
        final cm = cursor.year * 12 + (cursor.month - 1);
        return (cm - sm) ~/ rule.safeInterval;
      case RecurrenceFrequency.yearly:
        return (cursor.year - start.year) ~/ rule.safeInterval;
      case RecurrenceFrequency.once:
        return 0;
    }
  }

  bool _matches(DateTime day) {
    switch (rule.frequency) {
      case RecurrenceFrequency.once:
        final s = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
        return day.year == s.year && day.month == s.month && day.day == s.day;
      case RecurrenceFrequency.daily:
        return _dailyMatches(day);
      case RecurrenceFrequency.weekly:
        return _weeklyMatches(day);
      case RecurrenceFrequency.monthly:
        return _monthlyMatches(day);
      case RecurrenceFrequency.yearly:
        return _yearlyMatches(day);
    }
  }

  bool _dailyMatches(DateTime day) {
    final start = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
    if (day.isBefore(start)) return false;
    return day.difference(start).inDays % rule.safeInterval == 0;
  }

  bool _weeklyMatches(DateTime day) {
    final start = DateTime(rule.dtStart.year, rule.dtStart.month, rule.dtStart.day);
    if (day.isBefore(start)) return false;
    final weekDays = rule.byWeekDays.isEmpty ? [rule.dtStart.weekday] : rule.byWeekDays;
    if (!weekDays.contains(day.weekday)) return false;
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
      if (day.day == _resolveMonthDay(day.year, day.month, raw)) return true;
    }
    return false;
  }

  bool _yearlyMatches(DateTime day) {
    final start = rule.dtStart;
    if (day.year < start.year) return false;
    if ((day.year - start.year) % rule.safeInterval != 0) return false;
    if (day.month != start.month) return false;
    final targets = rule.byMonthDays.isEmpty ? [start.day] : rule.byMonthDays;
    for (final raw in targets) {
      if (day.day == _resolveMonthDay(day.year, day.month, raw)) return true;
    }
    return false;
  }

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// [raw] 1–31 or -1 (last day). Clamps to real last day (handles 31 Jan → 28/29 Feb).
  static int _resolveMonthDay(int year, int month, int raw) {
    final last = DateTime(year, month + 1, 0).day;
    if (raw == -1) return last;
    if (raw < 1) return 1;
    return raw > last ? last : raw;
  }

  static DateTime addMonthsClamped(DateTime from, int months, {int? dayOfMonth}) {
    final targetMonthIndex = from.year * 12 + (from.month - 1) + months;
    final y = targetMonthIndex ~/ 12;
    final m = targetMonthIndex % 12 + 1;
    final dom = _resolveMonthDay(y, m, dayOfMonth ?? from.day);
    return DateTime(y, m, dom, from.hour, from.minute, from.second);
  }
}

/// Facade for existing call sites (bills, habits, tasks).
class RecurrenceEngine {
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
      monthDay: monthDay ?? from.day,
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
      monthDay: from.day,
    );
    return rule.generator().generate(after: from, limit: limit).map((o) => o.startMs).toList();
  }
}
