import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../data/income_repository.dart';
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
    this.onPayBill,
  });

  final List<Expense> expenses;
  final List<Income> income;
  final List<BillOccurrence> billOcc;
  final int monthSpendMinor;
  final Future<void> Function() onChanged;
  final Future<void> Function(BillOccurrence o)? onPayBill;

  @override
  State<FinanceHub> createState() => _FinanceHubState();
}

class _FinanceHubState extends State<FinanceHub> {
  List<Map<String, Object?>> _accounts = [];
  List<Map<String, Object?>> _debts = [];
  List<Map<String, Object?>> _subs = [];
  List<Map<String, Object?>> _savings = [];
  int _monthIncomeMinor = 0;
  int _totalBalanceMinor = 0;

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    final accounts = await AccountRepository(AppDatabase.instance).list();
    final debts = await ExtendedRepository(AppDatabase.instance).listDebts();
    final subs = await ExtendedRepository(AppDatabase.instance).listSubscriptions();
    final savings = await ExtendedRepository(AppDatabase.instance).listSavings();
    final inc = await IncomeRepository(AppDatabase.instance).totalMinorThisMonth();
    final bal = await AccountRepository(AppDatabase.instance).totalBalanceMinor();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _debts = debts;
      _subs = subs;
      _savings = savings;
      _monthIncomeMinor = inc;
      _totalBalanceMinor = bal;
    });
  }

  Future<void> _refresh() async {
    await _loadExtra();
    await widget.onChanged();
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = 'MOBILE_MONEY';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Account', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, style: const TextStyle(color: AppTheme.silver), decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: AppTheme.metal,
                items: const [
                  DropdownMenuItem(value: 'MOBILE_MONEY', child: Text('Mobile money')),
                  DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(labelText: 'Balance (${Defaults.currency})'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty), child: const Text('Save')),
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
    await _refresh();
  }

  Future<void> _adjust(Map<String, Object?> a) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text('Adjust ${a['name']}', style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(labelText: 'Delta (${Defaults.currency})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok != true) return;
    final d = double.tryParse(ctrl.text.trim().replaceAll(',', ''));
    if (d == null || d == 0) return;
    await AccountRepository(AppDatabase.instance).adjustBalance(accountId: a['id'] as String, deltaMajor: d);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final spend = (widget.monthSpendMinor / 100).toStringAsFixed(2);
    final incomeStr = (_monthIncomeMinor / 100).toStringAsFixed(2);
    final net = ((_monthIncomeMinor - widget.monthSpendMinor) / 100).toStringAsFixed(2);
    final bal = (_totalBalanceMinor / 100).toStringAsFixed(2);
    final netOk = _monthIncomeMinor >= widget.monthSpendMinor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('Finance', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        Text('Accounts · cashflow · bills · debts · savings',
            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This month', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
              Row(children: [
                Expanded(child: Text('In ${Defaults.currency} $incomeStr', style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w700))),
                Expanded(child: Text('Out ${Defaults.currency} $spend', style: const TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w700))),
                Expanded(child: Text('Net ${Defaults.currency} $net', style: TextStyle(color: netOk ? AppTheme.woodLight : Colors.redAccent, fontWeight: FontWeight.w700))),
              ]),
              Text('Accounts total ${Defaults.currency} $bal', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton(onPressed: () async { if (await showCreateForm(context, AddKind.expense)) await _refresh(); }, child: const Text('Expense')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () async { if (await showCreateForm(context, AddKind.income)) await _refresh(); }, child: const Text('Income')),
              ]),
            ],
          ),
        ),
        _hdr('Accounts', _addAccount),
        if (_accounts.isEmpty)
          Text('No accounts', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._accounts.map((a) {
            final m = a['current_balance_minor'] as int? ?? 0;
            return GlassCard(
              child: ListTile(
                onTap: () => _adjust(a),
                title: Text('${a['name']}', style: const TextStyle(color: AppTheme.silver)),
                subtitle: Text('${a['type']} · tap to adjust', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                trailing: Text('${(m / 100).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.amber)),
              ),
            );
          }),
        _hdr('Bills', () async { if (await showCreateForm(context, AddKind.bill)) await _refresh(); }),
        if (widget.billOcc.isEmpty)
          Text('Nothing open', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...widget.billOcc.map((o) => GlassCard(
                child: ListTile(
                  title: Text(o.billName ?? 'Bill', style: const TextStyle(color: AppTheme.silver)),
                  trailing: widget.onPayBill == null
                      ? null
                      : FilledButton(onPressed: () async { await widget.onPayBill!(o); await _refresh(); }, child: const Text('Pay')),
                ),
              )),
        _hdr('Debts', () async {
          await ExtendedRepository(AppDatabase.instance).addDebt(title: 'Debt', amountMajor: 1000, direction: 'OWED_BY_ME');
          await _refresh();
        }),
        ..._debts.map((d) {
          final rem = d['remaining_amount_minor'] as int? ?? 0;
          return GlassCard(
            child: ListTile(
              title: Text('${d['title']}', style: const TextStyle(color: AppTheme.silver)),
              subtitle: Text('${d['direction']} · ${(rem / 100).toStringAsFixed(0)}', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
              trailing: TextButton(
                onPressed: () async {
                  await ExtendedRepository(AppDatabase.instance).payDebt(d['id'] as String, 100);
                  await _refresh();
                },
                child: const Text('Pay 100'),
              ),
            ),
          );
        }),
        _hdr('Subscriptions', () async {
          await ExtendedRepository(AppDatabase.instance).addSubscription('Subscription', 500);
          await _refresh();
        }),
        ..._subs.map((s) {
          final amt = s['amount_minor'] as int? ?? 0;
          return GlassCard(
            child: ListTile(
              title: Text('${s['service_name']}', style: const TextStyle(color: AppTheme.silver)),
              trailing: Text('${(amt / 100).toStringAsFixed(0)}/mo', style: const TextStyle(color: AppTheme.amber)),
            ),
          );
        }),
        _hdr('Savings', () async {
          await ExtendedRepository(AppDatabase.instance).addSavingsGoal('Goal', 10000);
          await _refresh();
        }),
        ..._savings.map((s) {
          final cur = s['current_amount_minor'] as int? ?? 0;
          final tgt = s['target_amount_minor'] as int? ?? 1;
          return GlassCard(
            child: ListTile(
              title: Text('${s['name']}', style: const TextStyle(color: AppTheme.silver)),
              subtitle: Text('${(cur / 100).toStringAsFixed(0)} / ${(tgt / 100).toStringAsFixed(0)}',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
              trailing: TextButton(
                onPressed: () async {
                  await ExtendedRepository(AppDatabase.instance).contributeSavings(s['id'] as String, 500);
                  await _refresh();
                },
                child: const Text('+500'),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('Recent expenses', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
        ...widget.expenses.take(8).map((e) => ListTile(
              dense: true,
              title: Text(e.description, style: const TextStyle(color: AppTheme.silver)),
              trailing: Text('-${(e.amountMinor / 100).toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent)),
            )),
      ],
    );
  }

  Widget _hdr(String title, Future<void> Function() onAdd) => Row(
        children: [
          Text(title, style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(onPressed: onAdd, child: const Text('Add')),
        ],
      );
}
