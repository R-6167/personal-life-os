import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact vertical chain of life nodes (goal → project → task…).
class LifeChain extends StatelessWidget {
  const LifeChain({super.key, required this.nodes});

  final List<({String label, String? sub})> nodes;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == 0 ? AppTheme.amber : AppTheme.woodLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < nodes.length - 1)
                    Container(
                      width: 2,
                      height: 22,
                      color: AppTheme.silver.withValues(alpha: 0.25),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nodes[i].label,
                        style: const TextStyle(
                          color: AppTheme.silver,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (nodes[i].sub != null && nodes[i].sub!.isNotEmpty)
                        Text(
                          nodes[i].sub!,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.items});

  final List<({String label, int at})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No activity yet',
        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
      );
    }
    return Column(
      children: items.map((a) {
        final d = DateTime.fromMillisecondsSinceEpoch(a.at);
        final stamp =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stamp,
                style: TextStyle(
                  color: AppTheme.silver.withValues(alpha: 0.35),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.label,
                  style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String humanEvent(String eventType) {
  const map = {
    'TASK_COMPLETED': 'Completed task',
    'TASK_CREATED': 'Added task',
    'TASK_SCHEDULED': 'Scheduled task',
    'TASK_RESCHEDULED': 'Rescheduled task',
    'TASK_UPDATED': 'Updated task',
    'TASK_REOPENED': 'Reopened task',
    'WORK_STARTED': 'Started work session',
    'WORK_COMPLETED': 'Finished work session',
    'WORK_PAUSED': 'Paused work',
    'WORK_RESUMED': 'Resumed work',
    'PROJECT_CREATED': 'Started project',
    'PROJECT_COMPLETED': 'Finished project',
    'GOAL_CREATED': 'Set goal',
    'GOAL_COMPLETED': 'Achieved goal',
    'MILESTONE_COMPLETED': 'Reached milestone',
    'MILESTONE_CREATED': 'Added milestone',
    'HABIT_COMPLETED': 'Completed habit',
    'HABIT_SKIPPED': 'Skipped habit',
    'HABIT_CREATED': 'Started habit',
    'ROUTINE_COMPLETED': 'Completed routine',
    'ROUTINE_MISSED': 'Missed routine',
    'ROUTINE_RECOVERED': 'Caught up routine',
    'BILL_PAID': 'Paid bill',
    'BILL_CREATED': 'Added bill',
    'EXPENSE_RECORDED': 'Recorded expense',
    'INCOME_RECORDED': 'Recorded income',
    'DEBT_PAYMENT_RECORDED': 'Debt payment',
    'DEBT_PAID_OFF': 'Cleared debt',
    'SAVINGS_CONTRIBUTION_RECORDED': 'Saved toward goal',
    'SAVINGS_GOAL_REACHED': 'Reached savings goal',
    'SUBSCRIPTION_PAID': 'Paid subscription',
    'SUBSCRIPTION_CREATED': 'Added subscription',
    'NOTE_CREATED': 'Wrote note',
    'NOTE_UPDATED': 'Updated note',
    'PRACTICAL_COMPLETED': 'Finished practical item',
    'DOCUMENT_RENEWED': 'Renewed document',
    'REMINDER_CREATED': 'Set reminder',
    'WELLNESS_CHECKIN': 'Wellness check-in',
    'BUDGET_CREATED': 'Set budget',
    'TIME_BLOCK_CREATED': 'Blocked time',
  };
  return map[eventType] ?? eventType.replaceAll('_', ' ').toLowerCase();
}
