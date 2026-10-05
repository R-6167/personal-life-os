import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Visual “one system” chain: Goal → Project → Milestone → Task → Schedule → Done.
class LifeChainBanner extends StatelessWidget {
  const LifeChainBanner({
    super.key,
    required this.steps,
    this.subtitle,
  });

  final List<String> steps;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            steps.join('  →  '),
            style: const TextStyle(
              color: AppTheme.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({
    super.key,
    required this.items,
  });

  final List<({String label, int at})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No activity yet on this thread',
        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 13),
      );
    }
    return Column(
      children: items.map((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
        final stamp =
            '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppTheme.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.label, style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                ),
                Text(stamp, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
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
