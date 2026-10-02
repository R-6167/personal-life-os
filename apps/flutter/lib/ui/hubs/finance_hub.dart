import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class FinanceHub extends StatefulWidget {
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
  State<FinanceHub> createState() => _FinanceHubState();
}

class _FinanceHubState extends State<FinanceHub> {
  List<Map<String, Object?>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final a = await AccountRepository(AppDatabase.instance).list();
    if (mounted) setState(() => _accounts = a);
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = 'CASH';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Financial account', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Name * (e.g. M-Pesa)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash / wallet')),
                  DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                  DropdownMenuItem(value: 'MOBILE_MONEY', child: Text('Mobile money')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => type = v ?? 'CASH'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(labelText: 'Balance (${Defaults.currency}) optional'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await AccountRepository(AppDatabase.instance).create(
      name: name.text.trim(),
      type: type,
      balanceMajor: double.tryParse(balance.text.trim().replaceAll(',', '')),
    );
    await _loadAccounts();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final spend = (widget.monthSpendMinor / 100).toStringAsFixed(2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('Finance', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Accounts · spend · bills · income',
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
                    Text('This month spent', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
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
                  if (ok) await widget.onChanged();
                },
                child: const Text('Expense'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final ok = await showCreateForm(context, AddKind.income);
                  if (ok) await widget.onChanged();
                },
                child: const Text('Income'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Accounts', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: _addAccount, child: const Text('Add')),
          ],
        ),
        if (_accounts.isEmpty)
          Text('e.g. M-Pesa, Equity — optional balances', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._accounts.map((a) {
            final bal = a['current_balance_minor'] as int?;
            final balStr = bal == null
                ? '—'
                : '${a['currency'] ?? Defaults.currency} ${(bal / 100).toStringAsFixed(2)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${a['name']}', style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                          Text('${a['type']}', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(balStr, style: const TextStyle(color: AppTheme.amber)),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Bills due', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final ok = await showCreateForm(context, AddKind.bill);
                if (ok) await widget.onChanged();
              },
              child: const Text('Add bill'),
            ),
          ],
        ),
        if (widget.billOcc.isEmpty)
          Text('Nothing open', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...widget.billOcc.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(o.billName ?? 'Bill', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(o.status, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                    trailing: FilledButton(
                      onPressed: () async {
                        await BillRepository(AppDatabase.instance).payOccurrence(o);
                        await widget.onChanged();
                        if (mounted) {
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
        ...widget.expenses.take(8).map((e) => ListTile(
              dense: true,
              title: Text(e.description, style: const TextStyle(color: AppTheme.silver)),
              trailing: Text(e.displayAmount, style: const TextStyle(color: AppTheme.amber)),
            )),
        ...widget.income.take(5).map((i) => ListTile(
              dense: true,
              title: Text(i.source, style: const TextStyle(color: AppTheme.silver)),
              trailing: Text(i.displayAmount, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7))),
            )),
      ],
    );
  }
}
