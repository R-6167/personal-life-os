import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/planning_repository.dart';

void main() {
  group('mergeBusyIntervals', () {
    test('empty', () {
      expect(mergeBusyIntervals(const []), isEmpty);
    });

    test('non-overlapping', () {
      const a = BusyInterval(0, 100);
      const b = BusyInterval(200, 300);
      final m = mergeBusyIntervals([a, b]);
      expect(m.length, 2);
      expect(m[0].startMs, 0);
      expect(m[1].startMs, 200);
    });

    test('overlapping are merged (no double-count)', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 100),
        const BusyInterval(50, 150),
      ]);
      expect(m.length, 1);
      expect(m.single.startMs, 0);
      expect(m.single.endMs, 150);
      expect(m.single.durationMs, 150);
    });

    test('adjacent intervals merge', () {
      final m = mergeBusyIntervals([
        const BusyInterval(0, 100),
        const BusyInterval(100, 200),
      ]);
      expect(m.length, 1);
      expect(m.single.endMs, 200);
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
}
