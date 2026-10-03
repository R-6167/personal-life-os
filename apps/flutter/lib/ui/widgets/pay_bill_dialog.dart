import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../theme.dart';

/// Prompt for amount + account before paying (expense + balance + next occurrence).
Future<bool> promptAndPayBill(BuildContext context, BillOccurrence occ) async {
  final expected = occ.expectedAmountMinor == null
      ? null
      : (occ.expectedAmountMinor! / 100).toStringAsFixed(2);
  final amount = TextEditingController(text: expected ?? '');
  final accounts = await AccountRepository(AppDatabase.instance).list();
  String? accountId = accounts.isEmpty ? null : accounts.first['id'] as String?;

  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(
          'Pay ${occ.billName ?? 'bill'}',
          style: const TextStyle(color: AppTheme.silver),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense → account balance → next bill occurrence',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(
                labelText: 'Amount paid (${occ.currency ?? Defaults.currency}) *',
              ),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: accountId,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Pay from account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text('${a['name']}'),
                    ),
                ],
                onChanged: (v) => setLocal(() => accountId = v),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (double.tryParse(amount.text.trim().replaceAll(',', '')) == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final major = double.parse(amount.text.trim().replaceAll(',', ''));
  await BillRepository(AppDatabase.instance).payOccurrence(
    occ,
    actualMajor: major,
    accountId: accountId,
  );
  return true;
}
