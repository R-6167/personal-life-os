import 'package:flutter/material.dart';

import '../../data/budget_repository.dart';
import '../../data/category_repository.dart';
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
  final _cats = CategoryRepository(AppDatabase.instance);
  List<BudgetStatus> _budgets = [];
  List<Map<String, Object?>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.statuses();
    final cats = await _cats.listExpense();
    if (!mounted) return;
    setState(() {
      _budgets = list;
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    String? categoryId = _categories.isEmpty ? null : _categories.first['id'] as String?;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Category budget', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Budget name'),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(labelText: 'Monthly limit (${Defaults.currency})'),
              ),
              if (_categories.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: categoryId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All spend (no category)')),
                    ..._categories.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text('${c['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => categoryId = v),
                )
              else
                Text(
                  'Default categories will be created on first use.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
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
    var budgetName = name.text.trim();
    if (budgetName.isEmpty && categoryId != null) {
      final cat = _categories.cast<Map<String, Object?>>().where((c) => c['id'] == categoryId);
      budgetName = cat.isEmpty ? 'Budget' : '${cat.first['name']} budget';
    }
    if (budgetName.isEmpty || major <= 0) return;
    await _repo.create(
      name: budgetName,
      amountMajor: major,
      categoryId: categoryId,
    );
    await _load();
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New category', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await _cats.createExpense(c.text.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Budgets'),
          actions: [
            TextButton(onPressed: _addCategory, child: const Text('Category')),
          ],
        ),
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
                      'Category budgets sum expenses tagged with that category this month. '
                      'Tag expenses when recording them. Alert at 80% and when exceeded.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_budgets.isEmpty)
                    Text(
                      'No budgets yet — pick a category (Food, Transport, …) and set a limit.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                    )
                  else
                    ..._budgets.map((b) {
                      final color = b.level == BudgetAlertLevel.exceeded
                          ? Colors.redAccent
                          : (b.level == BudgetAlertLevel.near
                              ? Colors.orangeAccent
                              : AppTheme.amber);
                      final label = b.level == BudgetAlertLevel.exceeded
                          ? 'Exceeded'
                          : (b.level == BudgetAlertLevel.near ? 'Near limit' : 'On track');
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
                                ' · ${b.scopeLabel}',
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
