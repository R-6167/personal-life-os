import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/ai/prompt_builder.dart';
import 'package:ordin/services/personal_context_engine.dart';

void main() {
  PersonalSituation s() => PersonalSituation(
        at: DateTime(2026, 1, 1, 9),
        currentStateLines: const ['hi'],
        pressure: [
          PressureItem(label: 'Bill due', kind: 'BILL', score: 50),
        ],
        availableMinutesToday: 90,
        busyMinutesToday: 100,
        capacityLabel: 'Moderate',
        priorityLines: const ['Pay bill'],
        contextLines: const [],
        opportunities: [
          OpportunityItem(title: 'Pay bill', reason: 'Due', score: 50),
        ],
        openTaskCount: 1,
        overdueCount: 0,
        dueTodayCount: 1,
        habitCount: 0,
        openBillCount: 1,
        projectCount: 0,
        attentionCount: 1,
        monthSpendMinor: 0,
      );

  test('full situation block is grounded', () {
    final block = AiPromptBuilder.situationBlock(s());
    expect(block, contains('PERSONAL CONTEXT'));
    expect(block, contains('do not invent'));
    expect(block, contains('Bill due'));
  });

  test('compact block is shorter but keeps pressure', () {
    final full = AiPromptBuilder.situationBlock(s());
    final compact = AiPromptBuilder.situationBlockCompact(s());
    expect(compact.length, lessThan(full.length));
    expect(compact, contains('Bill due'));
    expect(compact, contains('free 90m'));
  });
}
