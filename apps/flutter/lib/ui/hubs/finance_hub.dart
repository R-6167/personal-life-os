import 'package:flutter/material.dart';

import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Finance overview — bills, expenses, income (no silent defaults).
class FinanceHub extends StatelessWidget {
  const FinanceHub({
    super.key,
    required this.expenses,
    required this.income,
    required this.billOcc,
    required this.monthSpendMinor,
    required this.onChanged,
  });

  final List<Expense> expenses;
  final List<Income> income;
  final List<BillOccurrence> billOcc;
  final int monthSpendMinor;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final spend = (monthSpendMinor / 100).toStringAsFixed(2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('Finance', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Where money goes, what is due, what came in',
          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This month', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
                    Text(
                      '${Defaults.currency} $spend',
                      style: const TextStyle(color: AppTheme.amber, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await showCreateForm(context, AddKind.expense);
                  if (ok) await onChanged();
                },
                child: const Text('Expense'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final ok = await showCreateForm(context, AddKind.income);
                  if (ok) await onChanged();
                },
                child: const Text('Income'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Bills due', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final ok = await showCreateForm(context, AddKind.bill);
                if (ok) await onChanged();
              },
              child: const Text('Add bill'),
            ),
          ],
        ),
        if (billOcc.isEmpty)
          Text('Nothing open', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...billOcc.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(o.billName ?? 'Bill', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(o.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                    trailing: FilledButton(
                      onPressed: () async {
                        await BillRepository(AppDatabase.instance).payOccurrence(o);
                        await onChanged();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Paid — expense recorded')),
                          );
                        }
                      },
                      child: const Text('Pay'),
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 16),
        const Text('Recent', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...expenses.take(8).map((e) => ListTile(
              dense: true,
              title: Text(e.description, style: const TextStyle(color: AppTheme.silver)),
              trailing: Text(e.displayAmount, style: const TextStyle(color: AppTheme.amber)),
            )),
        ...income.take(5).map((i) => ListTile(
              dense: true,
              title: Text(i.source, style: const TextStyle(color: AppTheme.silver)),
              trailing: Text(i.displayAmount, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7))),
            )),
      ],
    );
  }
}
