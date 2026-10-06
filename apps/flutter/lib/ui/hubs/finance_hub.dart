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
  Map<String, Object?> _outlook = {};
  List<Map<String, Object?>> _reconcile = [];
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
    final outlook = await softFuture(
          () => _finance.cashFlowOutlook(daysAhead: 30),
          fallback: <String, Object?>{},
          label: 'finance.outlook',
        ) ??
        <String, Object?>{};
    final reconcile = await softFuture(
          () => _finance.reconcileAccounts(),
          fallback: <Map<String, Object?>>[],
          label: 'finance.reconcile',
        ) ??
        <Map<String, Object?>>[];
    final ledger = await softFuture(
          () => _finance.ledger(limit: 12),
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
      _outlook = outlook;
      _reconcile = reconcile;
      _ledger = ledger;
      _budgetAlerts = budgetAlerts;
    });
  }

  Future<void> _refresh() async {
    await _loadExtra();
    await widget.onChanged();
  }

  String _money(Object? minor) {
    final m = (minor is int) ? minor : 0;
    return MoneyText.formatMinor(m);
  }

  String _fmtMs(Object? ms) {
    if (ms is! int) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _payAmountDialog({
    required String title,
    double? presetMajor,
    required Future<void> Function(double amount, String? accountId) onPay,
  }) async {
    final amount = TextEditingController(
      text: presetMajor == null ? '' : presetMajor.toStringAsFixed(2),
    );
    String? accountId = _accounts.isNotEmpty ? _accounts.first['id'] as String? : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: Text(title, style: const TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(labelText: 'Amount (${Defaults.currency})'),
              ),
              if (_accounts.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: accountId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    ..._accounts.map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text('${a['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final major = double.parse(amount.text.trim().replaceAll(',', ''));
    await onPay(major, accountId);
    await _refresh();
  }

  Future<void> _subAction(Map<String, Object?> s, String action) async {
    final id = s['id'] as String;
    final ext = ExtendedRepository(AppDatabase.instance);
    if (action == 'pay') {
      await _payAmountDialog(
        title: 'Pay: ${s['service_name'] ?? s['name']}',
        presetMajor: ((s['amount_minor'] as int?) ?? 0) / 100.0,
        onPay: (amount, accountId) => _finance.paySubscription(
          subscriptionId: id,
          amountMajor: amount,
          accountId: accountId,
        ),
      );
      return;
    }
    if (action == 'pause') await ext.pauseSubscription(id);
    if (action == 'resume') await ext.resumeSubscription(id);
    if (action == 'cancel') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Cancel subscription?', style: TextStyle(color: AppTheme.silver)),
          content: Text(
            'Stop tracking ${s['service_name'] ?? 'this service'}?',
            style: const TextStyle(color: AppTheme.silver),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel it')),
          ],
        ),
      );
      if (ok == true) await ext.cancelSubscription(id);
    }
    await _refresh();
  }

  Future<void> _showDebtDetail(Map<String, Object?> d) async {
    final payments = await _finance.listDebtPayments(d['id'] as String);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.metal,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.silver.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('${d['title']}',
                style: const TextStyle(
                    color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              '${d['direction'] == 'OWED_BY_ME' ? 'You owe' : 'Owed to you'} · remaining ${_money(d['remaining_amount_minor'])}',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _payAmountDialog(
                  title: 'Pay debt: ${d['title']}',
                  presetMajor: null,
                  onPay: (amount, accountId) => _finance.payDebtFromAccount(
                    debtId: d['id'] as String,
                    amountMajor: amount,
                    accountId: accountId,
                  ),
                );
              },
              icon: const Icon(Icons.payments),
              label: const Text('Record payment'),
            ),
            const SizedBox(height: 12),
            const Text('Payment history',
                style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              Text('No payments yet',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
            else
              ...payments.take(8).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_fmtMs(p['occurred_at']),
                              style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                        ),
                        Text(_money(p['amount_minor']),
                            style: const TextStyle(color: AppTheme.amber, fontSize: 13)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavingsDetail(Map<String, Object?> s) async {
    final contribs = await _finance.listSavingsContributions(s['id'] as String);
    final current = (s['current_amount_minor'] as int?) ?? 0;
    final target = (s['target_amount_minor'] as int?) ?? 0;
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.metal,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.silver.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('${s['name']}',
                style: const TextStyle(
                    color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              '${_money(current)} of ${_money(target)} (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppTheme.silver.withValues(alpha: 0.12),
                color: pct >= 1 ? const Color(0xFF6BCB77) : AppTheme.amber,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _payAmountDialog(
                  title: 'Contribute: ${s['name']}',
                  presetMajor: null,
                  onPay: (amount, accountId) => _finance.contributeSavingsFromAccount(
                    goalId: s['id'] as String,
                    amountMajor: amount,
                    accountId: accountId,
                  ),
                );
              },
              icon: const Icon(Icons.savings),
              label: const Text('Contribute'),
            ),
            const SizedBox(height: 12),
            const Text('Contributions',
                style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (contribs.isEmpty)
              Text('None yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
            else
              ...contribs.take(8).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_fmtMs(c['occurred_at']),
                              style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                        ),
                        Text(_money(c['amount_minor']),
                            style: const TextStyle(color: AppTheme.amber, fontSize: 13)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    var type = 'CHECKING';
    final balance = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Account', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: AppTheme.metal,
                items: const [
                  DropdownMenuItem(value: 'CHECKING', child: Text('Checking')),
                  DropdownMenuItem(value: 'SAVINGS', child: Text('Savings')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Opening balance'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty),
                child: const Text('Save')),
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
              TextField(
                  controller: title,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(labelText: 'Title')),
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
            TextField(
                controller: name,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Service')),
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
    final accountId = _accounts.isNotEmpty ? _accounts.first['id'] as String? : null;
    await _finance.createSubscription(
      name: name.text.trim(),
      amountMajor: major,
      accountId: accountId,
    );
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
            TextField(
                controller: name,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Name')),
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

  Widget _hdr(String title, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: AppTheme.amber, size: 20),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final incomeStr = _money(_cash['income_minor']);
    final spendStr = _money(_cash['expense_minor'] ?? widget.monthSpendMinor);
    final netMinor = (_cash['net_minor'] as int?) ?? 0;
    final bal = _money(_cash['accounts_balance_minor']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This month',
                  style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('In $incomeStr · Out $spendStr',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7))),
              Text(
                'Net ${_money(netMinor)} · Balances $bal',
                style: TextStyle(
                  color: netMinor >= 0
                      ? const Color(0xFF6BCB77)
                      : Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('30-day outlook',
                  style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Obligations ${_money(_outlook['obligations_minor'])} · '
                'Runway ${_money(_outlook['runway_minor'])}'
                '${(_outlook['covered'] == true) ? '' : ' · shortfall ${_money(_outlook['shortfall_minor'])}'}',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
              ),
              if (_outlook['covered'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Balances may not cover upcoming bills/subs',
                    style: TextStyle(color: Colors.orangeAccent.withValues(alpha: 0.9), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_reconcile.any((r) => r['ok'] != true))
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reconciliation',
                    style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ..._reconcile.where((r) => r['ok'] != true).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${r['name']}: stored ${_money(r['stored_balance_minor'])} vs ledger ${_money(r['ledger_balance_minor'])} (drift ${_money(r['drift_minor'])})',
                        style: TextStyle(color: Colors.orangeAccent.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    )),
              ],
            ),
          ),
        if (_reconcile.any((r) => r['ok'] != true)) const SizedBox(height: 10),
        if (_reconcile.isNotEmpty && _reconcile.every((r) => r['ok'] == true))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Accounts reconciled',
              style: TextStyle(color: const Color(0xFF6BCB77).withValues(alpha: 0.85), fontSize: 12),
            ),
          ),
        if (_budgetAlerts.isNotEmpty) ...[
          ..._budgetAlerts.take(3).map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                  ),
                  child: Text(
                    'Budget: ${b.categoryName ?? b.name}',
                    style: const TextStyle(color: AppTheme.silver),
                  ),
                ),
              )),
        ],
        _hdr('Accounts', _addAccount),
        if (_accounts.isEmpty)
          Text('No accounts', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._accounts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: ListTile(
                    title: Text('${a['name']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(a['current_balance_minor']),
                        style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
        _hdr('Debts', _addDebt),
        if (_debts.isEmpty)
          Text('No open debts', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._debts.map((d) {
            final owe = d['direction'] == 'OWED_BY_ME';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => _showDebtDetail(d),
                child: ListTile(
                  title: Text('${d['title']}', style: const TextStyle(color: AppTheme.silver)),
                  subtitle: Text(
                    '${owe ? 'You owe' : 'Owed to you'} · tap for history',
                    style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                  ),
                  trailing: Text(_money(d['remaining_amount_minor']),
                      style: TextStyle(
                          color: owe ? Colors.orangeAccent : const Color(0xFF6BCB77))),
                ),
              ),
            );
          }),
        _hdr('Subscriptions', _addSub),
        if (_subs.isEmpty)
          Text('None', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._subs.map((s) {
            final status = '${s['status'] ?? 'ACTIVE'}';
            final paused = status == 'PAUSED';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                child: ListTile(
                  title: Text('${s['service_name'] ?? s['name']}',
                      style: TextStyle(
                        color: AppTheme.silver,
                        decoration: paused ? TextDecoration.lineThrough : null,
                      )),
                  subtitle: Text(
                    '${paused ? 'Paused' : 'Active'} · next ${_fmtMs(s['next_renewal_at'])} · ${s['frequency'] ?? 'MONTHLY'}',
                    style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_money(s['amount_minor']),
                          style: const TextStyle(color: AppTheme.amber)),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppTheme.silverMuted, size: 20),
                        color: AppTheme.metal,
                        onSelected: (v) => _subAction(s, v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'pay', child: Text('Pay / renew')),
                          if (paused)
                            const PopupMenuItem(value: 'resume', child: Text('Resume'))
                          else
                            const PopupMenuItem(value: 'pause', child: Text('Pause')),
                          const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _subAction(s, 'pay'),
                ),
              ),
            );
          }),
        _hdr('Savings', _addSavings),
        if (_savings.isEmpty)
          Text('None', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._savings.map((s) {
            final current = (s['current_amount_minor'] as int?) ?? 0;
            final target = (s['target_amount_minor'] as int?) ?? 0;
            final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
            final reached = '${s['status']}' == 'REACHED' || (target > 0 && current >= target);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => _showSavingsDetail(s),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${s['name']}',
                                style: const TextStyle(
                                    color: AppTheme.silver, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            reached ? 'Reached' : '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: reached ? const Color(0xFF6BCB77) : AppTheme.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppTheme.silver.withValues(alpha: 0.12),
                          color: reached ? const Color(0xFF6BCB77) : AppTheme.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_money(current)} / ${_money(target)} · tap for history',
                        style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        const Text('Recent',
            style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
        if (_ledger.isEmpty)
          Text('No movements yet',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ..._ledger.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  child: ListTile(
                    dense: true,
                    title: Text('${row['title']}', style: const TextStyle(color: AppTheme.silver)),
                    trailing: Text(_money(row['amount_minor']),
                        style: const TextStyle(color: AppTheme.amber)),
                  ),
                ),
              )),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => showCreateForm(context, AddKind.expense).then((_) => _refresh()),
          icon: const Icon(Icons.add),
          label: const Text('Record expense'),
        ),
      ],
    );
  }
}
