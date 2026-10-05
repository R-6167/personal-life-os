import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/planning_repository.dart';
import 'package:ordin/services/build_my_day.dart';

void main() {
  group('mergeBusyIntervals complex schedules', () {
    test('three overlapping events collapse to one span', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 60 * 60000),
        const BusyInterval(30 * 60000, 90 * 60000),
        const BusyInterval(80 * 60000, 120 * 60000),
      ]);
      expect(m.length, 1);
      expect(m.single.durationMs, 120 * 60000);
    });

    test('free minutes: overlapped busy is not double-counted', () {
      final busy = mergeBusyIntervals([
        BusyInterval(
          DateTime(2026, 6, 1, 9).millisecondsSinceEpoch,
          DateTime(2026, 6, 1, 11).millisecondsSinceEpoch,
        ),
        BusyInterval(
          DateTime(2026, 6, 1, 10).millisecondsSinceEpoch,
          DateTime(2026, 6, 1, 12).millisecondsSinceEpoch,
        ),
      ]);
      final busyMin = busy.fold<int>(0, (s, i) => s + i.durationMs ~/ 60000);
      expect(busyMin, 180);
      expect(480 - busyMin, 300);
    });
  });

  group('BuildMyDay heuristics (pure)', () {
    test('DaySlot minutes and labels', () {
      final s = DaySlot(
        start: DateTime(2026, 6, 1, 9, 0),
        end: DateTime(2026, 6, 1, 9, 45),
        title: 'Deep work',
        kind: DaySlotKind.task,
      );
      expect(s.minutes, 45);
      expect(s.timeLabel, '09:00–09:45');
    });

    test('candidates sort by score descending', () {
      final list = [
        const FlexibleCandidate(
          id: 'a',
          title: 'A',
          kind: DaySlotKind.task,
          durationMin: 30,
          score: 40,
          reason: '',
        ),
        const FlexibleCandidate(
          id: 'b',
          title: 'B',
          kind: DaySlotKind.task,
          durationMin: 30,
          score: 100,
          reason: '',
        ),
        const FlexibleCandidate(
          id: 'c',
          title: 'C',
          kind: DaySlotKind.task,
          durationMin: 30,
          score: 70,
          reason: '',
        ),
      ]..sort((a, b) => b.score.compareTo(a.score));
      expect(list.map((c) => c.id).toList(), ['b', 'c', 'a']);
    });
  });
}
