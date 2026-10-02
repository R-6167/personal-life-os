import 'package:flutter/material.dart';

import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../theme.dart';

/// Prompt for actual amount before paying (no silent default).
Future<bool> promptAndPayBill(BuildContext context, BillOccurrence occ) async {
  final expected = occ.expectedAmountMinor == null
      ? null
      : (occ.expectedAmountMinor! / 100).toStringAsFixed(2);
  final amount = TextEditingController(text: expected ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
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
            'Records an expense and marks this occurrence paid.',
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
  );
  if (ok != true) return false;
  final major = double.parse(amount.text.trim().replaceAll(',', ''));
  await BillRepository(AppDatabase.instance).payOccurrence(occ, actualMajor: major);
  return true;
}
