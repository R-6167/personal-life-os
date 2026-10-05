import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/personal_context_engine.dart';

void main() {
  group('PersonalSituation', () {
    PersonalSituation sample() => PersonalSituation(
          at: DateTime(2026, 6, 15, 10, 30),
          currentStateLines: ['Monday 10:30', '3 open tasks'],
          pressure: [
            PressureItem(
                label: 'Overdue: Tax', kind: 'OVERDUE_TASK', score: 100),
          ],
          availableMinutesToday: 120,
          busyMinutesToday: 300,
          capacityLabel: 'Moderate free time',
          priorityLines: ['Relieve pressure: Overdue: Tax'],
          contextLines: ['Recent: task completed ×2'],
          opportunities: [
            OpportunityItem(
              title: 'Tax',
              reason: 'Overdue',
              score: 100,
              estimatedMinutes: 45,
            ),
          ],
          openTaskCount: 3,
          overdueCount: 1,
          dueTodayCount: 1,
          habitCount: 2,
          openBillCount: 0,
          projectCount: 1,
          attentionCount: 1,
          monthSpendMinor: 50000,
        );

    test('narrative contains all six layers', () {
      final n = sample().narrative();
      expect(n, contains('CURRENT STATE'));
      expect(n, contains('PRESSURE'));
      expect(n, contains('CAPACITY'));
      expect(n, contains('PRIORITY'));
      expect(n, contains('CONTEXT'));
      expect(n, contains('OPPORTUNITY'));
      expect(n, contains('Overdue: Tax'));
      expect(n, contains('Offline'));
    });

    test('brief is one line with free and next', () {
      final b = sample().brief();
      expect(b, contains('Free'));
      expect(b, contains('Tax'));
      expect(b, contains('pressure'));
    });

    test('empty pressure still narrates calmly', () {
      final s = sample();
      final calm = PersonalSituation(
        at: s.at,
        currentStateLines: s.currentStateLines,
        pressure: const [],
        availableMinutesToday: 400,
        busyMinutesToday: 20,
        capacityLabel: 'Open runway',
        priorityLines: ['No urgent work'],
        contextLines: const [],
        opportunities: const [],
        openTaskCount: 0,
        overdueCount: 0,
        dueTodayCount: 0,
        habitCount: 0,
        openBillCount: 0,
        projectCount: 0,
        attentionCount: 0,
        monthSpendMinor: 0,
      );
      final n = calm.narrative();
      expect(n, contains('No critical pressure'));
      expect(n, contains('Capture a task'));
    });
  });
}
