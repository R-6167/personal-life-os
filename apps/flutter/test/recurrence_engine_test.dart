import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/recurrence_engine.dart';

void main() {
  group('RecurrenceRule / OccurrenceGenerator', () {
    test('daily interval 1', () {
      final rule = RecurrenceRule(
        dtStart: DateTime(2026, 1, 1, 9),
        frequency: RecurrenceFrequency.daily,
        interval: 1,
      );
      final next = rule.generator().nextAfter(DateTime(2026, 1, 1, 10));
      expect(next, isNotNull);
      expect(next!.day, 2);
      expect(next.hour, 9);
    });

    test('weekly with byWeekDays', () {
      final rule = RecurrenceRule.fromLegacy(
        frequency: 'WEEKLY',
        interval: 1,
        dtStart: DateTime(2026, 1, 5),
        daysOfWeek: [1, 3, 5],
      );
      final gen = rule.generator();
      final afterMon = gen.nextAfter(DateTime(2026, 1, 5, 12));
      expect(afterMon, isNotNull);
      expect(afterMon!.weekday, DateTime.wednesday);
    });

    test('monthly clamps day', () {
      final rule = RecurrenceRule.fromLegacy(
        frequency: 'MONTHLY',
        interval: 1,
        dtStart: DateTime(2026, 1, 31),
        monthDay: 31,
      );
      final next = rule.generator().nextAfter(DateTime(2026, 1, 31, 12));
      expect(next, isNotNull);
      expect(next!.month, 2);
      expect(next.day, lessThanOrEqualTo(29));
    });

    test('until stops generation', () {
      final rule = RecurrenceRule(
        dtStart: DateTime(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        until: DateTime(2026, 1, 3, 23, 59),
      );
      final gen = rule.generator();
      final a = gen.nextAfter(DateTime(2026, 1, 1));
      final b = gen.nextAfter(DateTime(2026, 1, 2));
      final c = gen.nextAfter(DateTime(2026, 1, 3));
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(c, isNull);
    });
  });
}
