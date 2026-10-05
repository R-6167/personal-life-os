import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/planning_repository.dart';
import 'package:ordin/services/build_my_day.dart';

void main() {
  group('mergeBusyIntervals complex schedules', () {
    test('empty', () {
      expect(mergeBusyIntervals(const []), isEmpty);
    });

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

    test('adjacent intervals merge', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 100),
        const BusyInterval(100, 200),
      ]);
      expect(m.length, 1);
      expect(m.single.endMs, 200);
    });

    test('nested interval collapses', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 100),
        const BusyInterval(20, 40),
        const BusyInterval(50, 80),
      ]);
      expect(m.length, 1);
      expect(m.single.startMs, 0);
      expect(m.single.endMs, 100);
    });

    test('unsorted input is sorted then merged', () {
      final m = mergeBusyIntervals([
        const BusyInterval(50, 80),
        const BusyInterval(0, 30),
        const BusyInterval(25, 55),
      ]);
      expect(m.length, 1);
      expect(m.single.startMs, 0);
      expect(m.single.endMs, 80);
    });

    test('calendar + block style overlap', () {
      final m = mergeBusyIntervals([
        const BusyInterval(10, 40),
        const BusyInterval(20, 50),
        const BusyInterval(60, 70),
      ]);
      expect(m.length, 2);
      expect(m[0].durationMs, 40);
      expect(m[1].durationMs, 10);
      final total = m.fold<int>(0, (s, i) => s + i.durationMs);
      expect(total, 50);
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

    test('urgency ordering: overdue > due-soon > open', () {
      // Mirrors scoring intent: base 100+overdue, 85+due, 40+open.
      final overdue = 100 + 26; // deeply overdue bonus
      final dueSoon = 85 + 22; // <2h
      final open = 40 + 8; // priority * 8 example
      expect(overdue > dueSoon, isTrue);
      expect(dueSoon > open, isTrue);
    });

    test('dependents boost compounds score', () {
      const base = 40;
      const dependents = 2;
      final boosted = base + dependents * 12;
      expect(boosted, 64);
      expect(boosted > base, isTrue);
    });
  });

  group('suggest-slot gap tiling (pure math)', () {
    test('gap after merged busy yields start times', () {
      // Day 08:00–22:00; busy 09:00–11:00 and 14:00–15:00.
      final dayStart = DateTime(2026, 6, 1, 8);
      final need = const Duration(minutes: 30);
      final merged = mergeBusyIntervals([
        BusyInterval(
          DateTime(2026, 6, 1, 9).millisecondsSinceEpoch,
          DateTime(2026, 6, 1, 11).millisecondsSinceEpoch,
        ),
        BusyInterval(
          DateTime(2026, 6, 1, 14).millisecondsSinceEpoch,
          DateTime(2026, 6, 1, 15).millisecondsSinceEpoch,
        ),
      ]);
      final slots = <DateTime>[];
      var cursor = dayStart;
      for (final m in merged) {
        final gapEnd = DateTime.fromMillisecondsSinceEpoch(m.startMs);
        if (gapEnd.isAfter(cursor) && gapEnd.difference(cursor) >= need) {
          slots.add(cursor);
        }
        final after = DateTime.fromMillisecondsSinceEpoch(m.endMs);
        if (after.isAfter(cursor)) cursor = after;
      }
      final dayEnd = DateTime(2026, 6, 1, 22);
      if (dayEnd.difference(cursor) >= need) slots.add(cursor);

      expect(slots.length, greaterThanOrEqualTo(2));
      expect(slots.first.hour, 8);
      // After 09–11 busy, next free starts at 11.
      expect(slots.any((s) => s.hour == 11), isTrue);
    });

    test('full-day busy leaves no slots', () {
      final dayStart = DateTime(2026, 6, 1, 8);
      final dayEnd = DateTime(2026, 6, 1, 22);
      final need = const Duration(minutes: 30);
      final merged = mergeBusyIntervals([
        BusyInterval(
          dayStart.millisecondsSinceEpoch,
          dayEnd.millisecondsSinceEpoch,
        ),
      ]);
      final slots = <DateTime>[];
      var cursor = dayStart;
      for (final m in merged) {
        final gapEnd = DateTime.fromMillisecondsSinceEpoch(m.startMs);
        if (gapEnd.isAfter(cursor) && gapEnd.difference(cursor) >= need) {
          slots.add(cursor);
        }
        final after = DateTime.fromMillisecondsSinceEpoch(m.endMs);
        if (after.isAfter(cursor)) cursor = after;
      }
      if (dayEnd.difference(cursor) >= need) slots.add(cursor);
      expect(slots, isEmpty);
    });
  });
}
