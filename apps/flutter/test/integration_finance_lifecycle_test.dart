import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/account_repository.dart';
import 'package:ordin/data/bill_repository.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/expense_repository.dart';
import 'package:ordin/data/income_repository.dart';
import 'package:ordin/domain/enums.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase appDb;

  setUp(() async {
    appDb = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('expense create is atomic with EXPENSE_RECORDED event', () async {
    final expenses = ExpenseRepository(appDb);
    final e = await expenses.create(
      description: 'Coffee',
      amountMajor: 4.50,
      currency: Defaults.currency,
    );

    final db = await appDb.database;
    final row =
        (await db.query('expenses', where: 'id = ?', whereArgs: [e.id])).single;
    expect(row['amount_minor'], 450);
    expect(row['description'], 'Coffee');

    final events = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'EXPENSE_RECORDED'",
      whereArgs: [e.id],
    );
    expect(events.length, 1);
    expect(events.first['entity_type'], 'EXPENSE');
  });

  test('income create credits account and records INCOME_RECORDED atomically', () async {
    final accounts = AccountRepository(appDb);
    final accountId = await accounts.create(
      name: 'Wallet',
      balanceMajor: 100.0,
      currency: Defaults.currency,
    );

    final income = IncomeRepository(appDb);
    final inc = await income.create(
      source: 'Freelance',
      amountMajor: 25.0,
      accountId: accountId,
      currency: Defaults.currency,
    );

    final db = await appDb.database;
    final acc = (await db.query(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    ))
        .single;
    expect(acc['current_balance_minor'], 12500); // 100 + 25

    final incRow =
        (await db.query('income', where: 'id = ?', whereArgs: [inc.id])).single;
    expect(incRow['amount_minor'], 2500);

    final events = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'INCOME_RECORDED'",
      whereArgs: [inc.id],
    );
    expect(events.length, 1);
  });

  test('bill pay is atomic: expense + balance debit + BILL_PAID + EXPENSE_RECORDED', () async {
    final accounts = AccountRepository(appDb);
    final accountId = await accounts.create(
      name: 'Checking',
      balanceMajor: 500.0,
      currency: Defaults.currency,
    );

    final bills = BillRepository(appDb);
    final bill = await bills.create(
      name: 'Internet',
      expectedMajor: 50.0,
      dueInDays: 0,
      frequency: 'MONTHLY',
      accountId: accountId,
    );

    final open = await bills.listOpenOccurrences();
    final occ = open.firstWhere((o) => o.billId == bill.id);

    await bills.payOccurrence(occ, actualMajor: 50.0, accountId: accountId);

    final db = await appDb.database;

    final occRow = (await db.query(
      'bill_occurrences',
      where: 'id = ?',
      whereArgs: [occ.id],
    ))
        .single;
    expect(occRow['status'], BillOccurrenceStatus.paid);
    expect(occRow['actual_amount_minor'], 5000);
    expect(occRow['expense_id'], isNotNull);

    final expenseId = occRow['expense_id'] as String;
    final exp = (await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    ))
        .single;
    expect(exp['amount_minor'], 5000);

    final acc = (await db.query(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    ))
        .single;
    expect(acc['current_balance_minor'], 45000); // 500 - 50

    final paidEvents = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'BILL_PAID'",
      whereArgs: [occ.id],
    );
    expect(paidEvents.length, 1);

    final expEvents = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'EXPENSE_RECORDED'",
      whereArgs: [expenseId],
    );
    expect(expEvents.length, 1);

    // Recurring monthly should have scheduled next occurrence
    final nextOccs = await db.query(
      'bill_occurrences',
      where: "bill_id = ? AND status = ?",
      whereArgs: [bill.id, BillOccurrenceStatus.upcoming],
    );
    expect(nextOccs, isNotEmpty);
  });
}
