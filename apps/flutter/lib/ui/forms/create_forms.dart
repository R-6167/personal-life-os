import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/expense_repository.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/income_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../data/routine_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../services/notification_service.dart';
import '../theme.dart';

enum AddKind {
  task,
  project,
  goal,
  habit,
  routine,
  event,
  note,
  expense,
  income,
  bill,
  person,
  reminder,
}

Future<bool> showUniversalAdd(BuildContext context) async {
  final kind = await showModalBottomSheet<AddKind>(
    context: context,
    backgroundColor: AppTheme.metal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
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
            const SizedBox(height: 16),
            const Text(
              'What do you want to add?',
              style: TextStyle(color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (AddKind.task, Icons.check_box_outlined, 'Task'),
                  (AddKind.project, Icons.folder_outlined, 'Project'),
                  (AddKind.goal, Icons.flag_outlined, 'Goal'),
                  (AddKind.habit, Icons.repeat, 'Habit'),
                  (AddKind.routine, Icons.playlist_play, 'Routine'),
                  (AddKind.event, Icons.event, 'Event'),
                  (AddKind.note, Icons.note_outlined, 'Note'),
                  (AddKind.expense, Icons.arrow_upward, 'Expense'),
                  (AddKind.income, Icons.arrow_downward, 'Income'),
                  (AddKind.bill, Icons.receipt_long, 'Bill'),
                  (AddKind.person, Icons.person_outline, 'Person'),
                  (AddKind.reminder, Icons.alarm, 'Reminder'),
                ])
                  ActionChip(
                    avatar: Icon(e.$2, size: 18, color: AppTheme.amber),
                    label: Text(e.$3),
                    onPressed: () => Navigator.pop(ctx, e.$1),
                    backgroundColor: AppTheme.metalDeep,
                    side: BorderSide(color: AppTheme.silver.withValues(alpha: 0.2)),
                    labelStyle: const TextStyle(color: AppTheme.silver),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (kind == null || !context.mounted) return false;
  return showCreateForm(context, kind);
}

Future<bool> showCreateForm(BuildContext context, AddKind kind) async {
  switch (kind) {
    case AddKind.task:
      return _taskForm(context);
    case AddKind.project:
      return _simpleText(
        context,
        title: 'New project',
        fields: const ['Title', 'Description (optional)'],
        onSave: (v) async {
          await ProjectRepository(AppDatabase.instance).create(title: v[0]);
        },
      );
    case AddKind.goal:
      return _simpleText(
        context,
        title: 'New goal',
        fields: const ['Title', 'Description (optional)'],
        onSave: (v) async {
          await GoalRepository(AppDatabase.instance).create(title: v[0]);
        },
      );
    case AddKind.habit:
      return _simpleText(
        context,
        title: 'New habit',
        fields: const ['Title', 'Description (optional)'],
        onSave: (v) async {
          await HabitRepository(AppDatabase.instance).create(
            title: v[0],
            description: v.length > 1 ? v[1] : null,
          );
        },
      );
    case AddKind.routine:
      return _simpleText(
        context,
        title: 'New routine',
        fields: const ['Name'],
        onSave: (v) async {
          await RoutineRepository(AppDatabase.instance).create(name: v[0]);
        },
      );
    case AddKind.event:
      return _simpleText(
        context,
        title: 'New event',
        fields: const ['Title'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addEvent(title: v[0]);
        },
      );
    case AddKind.note:
      return _simpleText(
        context,
        title: 'New note',
        fields: const ['Content'],
        onSave: (v) async {
          await NoteRepository(AppDatabase.instance).create(content: v[0]);
        },
      );
    case AddKind.expense:
      return _moneyForm(context, isIncome: false);
    case AddKind.income:
      return _moneyForm(context, isIncome: true);
    case AddKind.bill:
      return _billForm(context);
    case AddKind.person:
      return _simpleText(
        context,
        title: 'New person',
        fields: const ['Name', 'Phone (optional)'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addPerson(
            v[0],
            phone: v.length > 1 && v[1].isNotEmpty ? v[1] : null,
          );
        },
      );
    case AddKind.reminder:
      return _simpleText(
        context,
        title: 'New reminder',
        fields: const ['Title'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addReminder(v[0]);
        },
      );
  }
}

Future<bool> _taskForm(BuildContext context) async {
  final title = TextEditingController();
  final desc = TextEditingController();
  var priority = 0;
  DateTime? due;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New task', style: TextStyle(color: AppTheme.silver)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: desc,
                style: const TextStyle(color: AppTheme.silver),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: priority,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Normal')),
                  DropdownMenuItem(value: 1, child: Text('High')),
                  DropdownMenuItem(value: 2, child: Text('Urgent')),
                ],
                onChanged: (v) => setLocal(() => priority = v ?? 0),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  due == null
                      ? 'Due date (optional)'
                      : 'Due: ${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today, color: AppTheme.amber, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setLocal(() => due = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (ok != true) return false;
  final dueMs = due == null
      ? null
      : DateTime(due!.year, due!.month, due!.day, 23, 59).millisecondsSinceEpoch;
  await TaskRepository(AppDatabase.instance).create(
    title: title.text.trim(),
    dueAt: dueMs,
    priority: priority,
    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
  );
  return true;
}

Future<bool> _moneyForm(BuildContext context, {required bool isIncome}) async {
  final label = TextEditingController();
  final amount = TextEditingController();
  final accounts = await AccountRepository(AppDatabase.instance).list();
  final categories = isIncome
      ? <Map<String, Object?>>[]
      : await CategoryRepository(AppDatabase.instance).listExpense();
  String? accountId;
  String? categoryId = categories.isEmpty ? null : categories.first['id'] as String?;

  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(
          isIncome ? 'Record income' : 'Record expense',
          style: const TextStyle(color: AppTheme.silver),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(
                  labelText: isIncome ? 'Source *' : 'What for? *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(
                  labelText: 'Amount (${Defaults.currency}) *',
                ),
              ),
              if (!isIncome && categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: categoryId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...categories.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text('${c['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => categoryId = v),
                ),
              ],
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: accountId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Account (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...accounts.map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text('${a['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isEmpty) return;
              if (double.tryParse(amount.text.trim().replaceAll(',', '')) == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final a = double.parse(amount.text.trim().replaceAll(',', ''));
  if (isIncome) {
    await IncomeRepository(AppDatabase.instance).create(
      source: label.text.trim(),
      amountMajor: a,
      accountId: accountId,
    );
  } else {
    await ExpenseRepository(AppDatabase.instance).create(
      description: label.text.trim(),
      amountMajor: a,
      accountId: accountId,
      categoryId: categoryId,
    );
    final alerts =
        await NotificationService.instance.checkCategoryAfterExpense(categoryId);
    if (alerts.isNotEmpty && context.mounted) {
      final b = alerts.first;
      final exceeded = b.level == BudgetAlertLevel.exceeded;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exceeded
                ? 'Budget exceeded: ${b.categoryName ?? b.name}'
                : 'Budget warning: ${b.categoryName ?? b.name}',
          ),
          backgroundColor: exceeded ? Colors.redAccent : Colors.orangeAccent,
        ),
      );
    }
  }
  return true;
}

Future<bool> _billForm(BuildContext context) async {
  final name = TextEditingController();
  final amount = TextEditingController();
  var dueInDays = 7;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New bill', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(
                labelText: 'Expected amount (${Defaults.currency})',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: dueInDays,
              dropdownColor: AppTheme.metal,
              decoration: const InputDecoration(labelText: 'Due in'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 7, child: Text('1 week')),
                DropdownMenuItem(value: 14, child: Text('2 weeks')),
                DropdownMenuItem(value: 30, child: Text('1 month')),
              ],
              onChanged: (v) => setLocal(() => dueInDays = v ?? 7),
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
  if (ok != true) return false;
  final major = double.tryParse(amount.text.trim().replaceAll(',', ''));
  await BillRepository(AppDatabase.instance).create(
    name: name.text.trim(),
    expectedMajor: major,
    dueInDays: dueInDays,
  );
  return true;
}

Future<bool> _simpleText(
  BuildContext context, {
  required String title,
  required List<String> fields,
  required Future<void> Function(List<String>) onSave,
}) async {
  final ctrls = List.generate(fields.length, (_) => TextEditingController());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.metal,
      title: Text(title, style: const TextStyle(color: AppTheme.silver)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            TextField(
              controller: ctrls[i],
              autofocus: i == 0,
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(labelText: fields[i]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (ctrls.first.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await onSave(ctrls.map((c) => c.text.trim()).toList());
  return true;
}
