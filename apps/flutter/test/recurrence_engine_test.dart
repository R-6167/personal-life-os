import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/recurrence_engine.dart';

void main() {
  group('RecurrenceRule / OccurrenceGenerator', () {
    test('daily nextAfter advances by interval', () {
      final rule = RecurrenceRule(
        dtStart: DateTime(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 2,
      );
      final gen = rule.generator();
      final next = gen.nextAfter(DateTime(2026, 1, 1, 12));
      expect(next, isNotNull);
      expect(next!.day, 3);
    });

    test('weekly respects byWeekDays', () {
      final rule = RecurrenceRule.fromLegacy(
        frequency: 'WEEKLY',
        interval: 1,
        dtStart: DateTime(2026, 1, 5), // Monday
        daysOfWeekCsv: 'MON,WED,FRI',
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

    test('idempotent nextAfter same cursor', () {
      final rule = RecurrenceRule(
        dtStart: DateTime(2026, 5, 1),
        frequency: RecurrenceFrequency.daily,
      );
      final gen = rule.generator();
      final cursor = DateTime(2026, 5, 1, 12);
      final a = gen.nextAfter(cursor);
      final b = gen.nextAfter(cursor);
      expect(a, isNotNull);
      expect(a, equals(b));
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
