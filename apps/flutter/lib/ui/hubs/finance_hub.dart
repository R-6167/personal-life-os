import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../services/finance_service.dart';
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
  final _finance = FinanceService();
  List<Map<String, Object?>> _accounts = [];
  List<Map<String, Object?>> _debts = [];
  List<Map<String, Object?>> _subs = [];
  List<Map<String, Object?>> _savings = [];
  List<Map<String, Object?>> _ledger = [];
  Map<String, Object?> _cash = {};

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    await BillRepository(AppDatabase.instance).refreshOccurrenceStatuses();
    final accounts = await AccountRepository(AppDatabase.instance).list();
    final debts = await ExtendedRepository(AppDatabase.instance).listDebts();
    final subs = await ExtendedRepository(AppDatabase.instance).listSubscriptions();
    final savings = await ExtendedRepository(AppDatabase.instance).listSavings();
    final cash = await _finance.cashFlowThisMonth();
    final ledger = await _finance.ledger(limit: 20);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _debts = debts;
      _subs = subs;
      _savings = savings;
      _cash = cash;
      _ledger = ledger;
    });
  }

  Future<void> _refresh() async {
    await _loadExtra();
    await widget.onChanged();
  }

  String _money(Object? minor) {
    final m = (minor as int?) ?? 0;
    return '${Defaults.currency} ${(m / 100).toStringAsFixed(2)}';
  }

  Future<String?> _pickAccount() async {
    if (_accounts.isEmpty) return null;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('Choose account', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
            ),
            ..._accounts.map((a) => ListTile(
                  title: Text('${a['name']}', style: const TextStyle(color: AppTheme.silver)),
                  subtitle: Text(_money(a['current_balance_minor']),
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45))),
                  onTap: () => Navigator.pop(ctx, a['id'] as String),
                )),
          ],
        ),
      ),
    );
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
                decoration: InputDecoration(labelText: 'Opening balance (${Defaults.currency})'),
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

  Future<void> _addDebt() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var direction = 'OWED_BY_ME';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Debt', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, style: const TextStyle(color: AppTheme.silver), decoration: const InputDecoration(labelText: 'Title')),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(labelText: 'Amount (${Defaults.currency})'),
              ),
              DropdownButtonFormField<String>(
                value: direction,
                dropdownColor: AppTheme.metal,
                items: const [
                  DropdownMenuItem(value: 'OWED_BY_ME', child: Text('I owe')),
                  DropdownMenuItem(value: 'OWED_TO_ME', child: Text('Owed to me')),
                ],
                onChanged: (v) => setLocal(() => direction = v ?? direction),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final major = double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
    if (title.text.trim().isEmpty || major <= 0) return;
    await ExtendedRepository(AppDatabase.instance).addDebt(
      title: title.text.trim(),
      amountMajor: major,
      direction: direction,
    );
    await _refresh();
  }

  Future<void> _addSub() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Subscription', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, style: const TextStyle(color: AppTheme.silver), decoration: const InputDecoration(labelText: 'Service')),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(labelText: 'Monthly (${Defaults.currency})'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final major = double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
    if (name.text.trim().isEmpty) return;
    await ExtendedRepository(AppDatabase.instance).addSubscription(name.text.trim(), major);
    await _refresh();
  }

  Future<void> _addSavings() async {
    final name = TextEditingController();
    final target = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Savings goal', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, style: const TextStyle(color: AppTheme.silver), decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(labelText: 'Target (${Defaults.currency})'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final major = double.tryParse(target.text.trim().replaceAll(',', '')) ?? 0;
    if (name.text.trim().isEmpty) return;
    await ExtendedRepository(AppDatabase.instance).addSavingsGoal(name.text.trim(), major);
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
    final incomeStr = _money(_cash['income_minor']);
    final spendStr = _money(_cash['expense_minor'] ?? widget.monthSpendMinor);
    final netMinor = (_cash['net_minor'] as int?) ?? 0;
    final netOk = netMinor >= 0;
    final bal = _money(_cash['accounts_balance_minor']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('Finance', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        Text('Connected accounts · bills · debts · savings · history',
            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cash flow this month',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('In $incomeStr', style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w700))),
                Expanded(child: Text('Out $spendStr', style: const TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w700))),
              ]),
              Text(
                'Net ${Defaults.currency} ${(netMinor / 100).toStringAsFixed(2)}',
                style: TextStyle(color: netOk ? AppTheme.woodLight : Colors.redAccent, fontWeight: FontWeight.w700),
              ),
              Text('Accounts $bal · bills due ${_money(_cash['bills_open_minor'])}',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.65), fontSize: 12)),
              Text(
                'Debt I owe ${_money(_cash['debt_owed_by_me_minor'])} · owed to me ${_money(_cash['debt_owed_to_me_minor'])}',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 11),
              ),
              Text('Subscriptions ~${_money(_cash['subscriptions_monthly_minor'])}/mo',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 11)),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton(
                  onPressed: () async {
                    if (await showCreateForm(context, AddKind.expense)) await _refresh();
                  },
                  child: const Text('Expense'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    if (await showCreateForm(context, AddKind.income)) await _refresh();
                  },
                  child: const Text('Income'),
                ),
              ]),
            ],
          ),
        ),
        _hdr('Accounts', _addAccount),
        if (_accounts.isEmpty)
          Text('Add an account so payments can update balances',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._accounts.map((a) {
            final m = a['current_balance_minor'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                child: ListTile(
                  onTap: () => _adjust(a),
                  title: Text('${a['name']}', style: const TextStyle(color: AppTheme.silver)),
                  subtitle: Text('${a['type']} · tap to adjust',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                  trailing: Text((m / 100).toStringAsFixed(2), style: const TextStyle(color: AppTheme.amber)),
                ),
              ),
            );
          }),
        _hdr('Bills', () async {
          if (await showCreateForm(context, AddKind.bill)) await _refresh();
        }),
        if (widget.billOcc.isEmpty)
          Text('Nothing open', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...widget.billOcc.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    title: Text(o.billName ?? 'Bill', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(
                      o.expectedAmountMinor == null
                          ? o.status
                          : '${(o.expectedAmountMinor! / 100).toStringAsFixed(0)} · ${o.status}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                    ),
                    trailing: widget.onPayBill == null
                        ? null
                        : FilledButton(
                            onPressed: () async {
                              await widget.onPayBill!(o);
                              await _refresh();
                            },
                            child: const Text('Pay'),
                          ),
                  ),
                ),
              )),
        _hdr('Debts', _addDebt),
        ..._debts.map((d) {
          final rem = d['remaining_amount_minor'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: ListTile(
                title: Text('${d['title']}', style: const TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  '${d['direction']} · remaining ${(rem / 100).toStringAsFixed(0)}',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final accountId = await _pickAccount();
                    final ctrl = TextEditingController(text: '100');
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.metal,
                        title: const Text('Debt payment', style: TextStyle(color: AppTheme.silver)),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.silver),
                          decoration: InputDecoration(labelText: 'Amount (${Defaults.currency})'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final major = double.tryParse(ctrl.text.trim().replaceAll(',', '')) ?? 0;
                    if (major <= 0) return;
                    await _finance.payDebtFromAccount(
                      debtId: d['id'] as String,
                      amountMajor: major,
                      accountId: accountId,
                    );
                    await _refresh();
                  },
                  child: const Text('Pay'),
                ),
              ),
            ),
          );
        }),
        _hdr('Subscriptions', _addSub),
        ..._subs.map((s) {
          final amt = s['amount_minor'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: ListTile(
                title: Text('${s['service_name']}', style: const TextStyle(color: AppTheme.silver)),
                trailing: Text('${(amt / 100).toStringAsFixed(0)}/mo', style: const TextStyle(color: AppTheme.amber)),
              ),
            ),
          );
        }),
        _hdr('Savings', _addSavings),
        ..._savings.map((s) {
          final cur = s['current_amount_minor'] as int? ?? 0;
          final tgt = s['target_amount_minor'] as int? ?? 1;
          final ratio = tgt == 0 ? 0.0 : (cur / tgt).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['name']}', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(
                      '${(cur / 100).toStringAsFixed(0)} / ${(tgt / 100).toStringAsFixed(0)}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final accountId = await _pickAccount();
                        final ctrl = TextEditingController(text: '500');
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.metal,
                            title: const Text('Contribute', style: TextStyle(color: AppTheme.silver)),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppTheme.silver),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        final major = double.tryParse(ctrl.text.trim().replaceAll(',', '')) ?? 0;
                        if (major <= 0) return;
                        await _finance.contributeSavingsFromAccount(
                          goalId: s['id'] as String,
                          amountMajor: major,
                          accountId: accountId,
                        );
                        await _refresh();
                      },
                      child: const Text('Add'),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: ratio,
                    color: AppTheme.amber,
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('Ledger (recent)', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (_ledger.isEmpty)
          Text('Income and expenses appear here for reconciliation',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._ledger.map((row) {
            final isExpense = row['kind'] == 'EXPENSE';
            final amt = (row['amount_minor'] as int?) ?? 0;
            return ListTile(
              dense: true,
              title: Text('${row['title']}', style: const TextStyle(color: AppTheme.silver)),
              subtitle: Text('${row['kind']}', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
              trailing: Text(
                '${isExpense ? '-' : '+'}${(amt / 100).toStringAsFixed(2)}',
                style: TextStyle(color: isExpense ? Colors.redAccent : AppTheme.woodLight),
              ),
            );
          }),
      ],
    );
  }

  Widget _hdr(String title, Future<void> Function() onAdd) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Text(title, style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      );
}
