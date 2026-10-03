import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/budget_repository.dart';
import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../services/finance_service.dart';
import '../../utils/soft_future.dart';
import '../forms/create_forms.dart';
import '../screens/budgets_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/money_text.dart';

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
  List<BudgetStatus> _budgetAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    await softRun(
      () => BillRepository(AppDatabase.instance).refreshOccurrenceStatuses(),
      label: 'finance.bills.refresh',
    );
    final accounts = await softFuture(
          () => AccountRepository(AppDatabase.instance).list(),
          fallback: <Map<String, Object?>>[],
          label: 'finance.accounts',
        ) ??
        <Map<String, Object?>>[];
    final debts = await softFuture(
          () => ExtendedRepository(AppDatabase.instance).listDebts(),
          fallback: <Map<String, Object?>>[],
          label: 'finance.debts',
        ) ??
        <Map<String, Object?>>[];
    final subs = await softFuture(
          () => ExtendedRepository(AppDatabase.instance).listSubscriptions(),
          fallback: <Map<String, Object?>>[],
          label: 'finance.subs',
        ) ??
        <Map<String, Object?>>[];
    final savings = await softFuture(
          () => ExtendedRepository(AppDatabase.instance).listSavings(),
          fallback: <Map<String, Object?>>[],
          label: 'finance.savings',
        ) ??
        <Map<String, Object?>>[];
    final cash = await softFuture(
          () => _finance.cashFlowThisMonth(),
          fallback: <String, Object?>{},
          label: 'finance.cash',
        ) ??
        <String, Object?>{};
    final ledger = await softFuture(
          () => _finance.ledger(limit: 20),
          fallback: <Map<String, Object?>>[],
          label: 'finance.ledger',
        ) ??
        <Map<String, Object?>>[];
    final budgetAlerts = await softFuture(
          () => BudgetRepository(AppDatabase.instance).alerts(),
          fallback: <BudgetStatus>[],
          label: 'finance.budgets',
        ) ??
        <BudgetStatus>[];
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _debts = debts;
      _subs = subs;
      _savings = savings;
      _cash = cash;
      _ledger = ledger;
      _budgetAlerts = budgetAlerts;
    });
  }

  Future<void> _refresh() async {
    await _loadExtra();
    await widget.onChanged();
  }

  String _money(Object? minor) => formatMoneyMinor(minor);

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

  Widget _hdr(String title, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      );

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
        // AppBar shows Finance — no second title.
        if (_budgetAlerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const BudgetsScreen()))
                    .then((_) => _refresh());
              },
              child: Text(
                'Budget alerts · ${_budgetAlerts.length}',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700),
              ),
            ),
          ),
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
                'Net ${_money(netMinor)}',
                style: TextStyle(color: netOk ? AppTheme.woodLight : Colors.redAccent, fontWeight: FontWeight.w700),
              ),
              Text('Accounts $bal',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.65), fontSize: 12)),
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
          ..._accounts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    onTap: () => _adjust(a),
                    title: Text('${a['name']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(a['current_balance_minor']), style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
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
                    trailing: FilledButton(
                      onPressed: () async {
                        if (widget.onPayBill != null) await widget.onPayBill!(o);
                        await _refresh();
                      },
                      child: const Text('Pay'),
                    ),
                  ),
                ),
              )),
        _hdr('Debts', _addDebt),
        if (_debts.isEmpty)
          Text('No open debts', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._debts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    title: Text('${d['title']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(d['remaining_amount_minor']), style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
        _hdr('Subscriptions', _addSub),
        if (_subs.isEmpty)
          Text('None', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._subs.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    title: Text('${s['service_name'] ?? s['name']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(s['amount_minor']), style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
        _hdr('Savings', _addSavings),
        if (_savings.isEmpty)
          Text('None', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._savings.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    title: Text('${s['name']}', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text(
                      '${_money(s['current_amount_minor'])} / ${_money(s['target_amount_minor'])}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 16),
        const Text('Recent', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
        if (_ledger.isEmpty)
          Text('No movements yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._ledger.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  child: ListTile(
                    dense: true,
                    title: Text('${row['title']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(row['amount_minor']), style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
      ],
    );
  }
}
