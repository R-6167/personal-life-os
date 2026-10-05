import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/planning_repository.dart';
import 'package:ordin/services/ai/ai_types.dart';
import 'package:ordin/services/recurrence_engine.dart';

/// Smoke: critical pure domain paths keep working without a device DB.
void main() {
  group('smoke · planning capacity', () {
    test('merged busy time never double-counts overlap', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 60 * 60000),
        const BusyInterval(30 * 60000, 90 * 60000),
      ]);
      expect(m.length, 1);
      expect(m.single.durationMs, 90 * 60000);
    });
  });

  group('smoke · recurrence', () {
    test('daily chain produces ordered days', () {
      final rule = RecurrenceRule(
        dtStart: DateTime(2026, 3, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 1,
      );
      final gen = rule.generator();
      final a = gen.nextAfter(DateTime(2026, 3, 1));
      final b = gen.nextAfter(a!);
      expect(a.day, 2);
      expect(b!.day, 3);
    });
  });

  group('smoke · AI mode matrix', () {
    test('every mode is serializable', () {
      for (final mode in AiMode.values) {
        final s = AiSettings(mode: mode);
        final back = AiSettings.fromJson(s.toJson());
        expect(back.mode, mode, reason: mode.name);
      }
    });
  });
}
