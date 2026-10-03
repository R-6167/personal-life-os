import 'package:flutter/material.dart';

import '../../data/budget_repository.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _repo = BudgetRepository(AppDatabase.instance);
  List<BudgetStatus> _budgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.statuses();
    if (!mounted) return;
    setState(() {
      _budgets = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final match = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Monthly budget', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Name (e.g. Food)'),
            ),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(labelText: 'Limit (${Defaults.currency})'),
            ),
            TextField(
              controller: match,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(
                labelText: 'Match keyword (optional)',
                helperText: 'Matches description/merchant. Empty = all spend.',
              ),
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
    if (name.text.trim().isEmpty || major <= 0) return;
    await _repo.create(
      name: name.text.trim(),
      amountMajor: major,
      matchKey: match.text.trim().isEmpty ? null : match.text.trim(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Budgets')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Budget'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  GlassCard(
                    child: Text(
                      'Monthly limits. Warning at 80% of limit; alert when exceeded. '
                      'Keyword match filters expenses by description or merchant.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_budgets.isEmpty)
                    Text(
                      'No budgets yet — add a food, transport, or overall limit.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                    )
                  else
                    ..._budgets.map((b) {
                      final color = b.level == BudgetAlertLevel.exceeded
                          ? Colors.redAccent
                          : (b.level == BudgetAlertLevel.warning
                              ? Colors.orangeAccent
                              : AppTheme.amber);
                      final label = b.level == BudgetAlertLevel.exceeded
                          ? 'Exceeded'
                          : (b.level == BudgetAlertLevel.warning ? 'Near limit' : 'On track');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.name,
                                      style: const TextStyle(
                                        color: AppTheme.silver,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(label, style: TextStyle(color: color, fontSize: 12)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.silverMuted),
                                    onPressed: () async {
                                      await _repo.delete(b.id);
                                      await _load();
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                '${(b.spentMinor / 100).toStringAsFixed(0)} / '
                                '${(b.limitMinor / 100).toStringAsFixed(0)} ${Defaults.currency}'
                                '${b.matchKey == null ? ' · all spend' : ' · match: ${b.matchKey}'}',
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: b.ratio.clamp(0.0, 1.0),
                                color: color,
                                backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Remaining ${(b.remainingMinor / 100).toStringAsFixed(0)} · '
                                '${(b.ratio * 100).toStringAsFixed(0)}% used',
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
