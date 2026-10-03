import '../data/account_repository.dart';
import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/income_repository.dart';
import '../domain/enums.dart';
import 'domain_recurrence.dart';
import 'recurrence_engine.dart';

/// Connected financial operations — one system, not isolated screens.
class FinanceService {
  FinanceService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  AccountRepository get accounts => AccountRepository(_db);
  BillRepository get bills => BillRepository(_db);
  ExpenseRepository get expenses => ExpenseRepository(_db);
  IncomeRepository get income => IncomeRepository(_db);
  ExtendedRepository get ext => ExtendedRepository(_db);

  Future<Map<String, Object?>> cashFlowThisMonth() async {
    final inMinor = await income.totalMinorThisMonth();
    final outMinor = await expenses.totalMinorThisMonth();
    final bal = await accounts.totalBalanceMinor();
    final openBills = await bills.listOpenOccurrences();
    var billsDueMinor = 0;
    for (final o in openBills) {
      billsDueMinor += o.expectedAmountMinor ?? 0;
    }
    final debts = await ext.listDebts();
    var debtOwedByMe = 0;
    var debtOwedToMe = 0;
    for (final d in debts) {
      final rem = (d['remaining_amount_minor'] as int?) ?? 0;
      if (d['direction'] == 'OWED_BY_ME') {
        debtOwedByMe += rem;
      } else {
        debtOwedToMe += rem;
      }
    }
    final subs = await ext.listSubscriptions();
    var subsMonthly = 0;
    for (final s in subs) {
      subsMonthly += (s['amount_minor'] as int?) ?? 0;
    }
    final savings = await ext.listSavings();
    var savingsTotal = 0;
    for (final s in savings) {
      savingsTotal += (s['current_amount_minor'] as int?) ?? 0;
    }
    return {
      'income_minor': inMinor,
      'expense_minor': outMinor,
      'net_minor': inMinor - outMinor,
      'accounts_balance_minor': bal,
      'bills_open_minor': billsDueMinor,
      'debt_owed_by_me_minor': debtOwedByMe,
      'debt_owed_to_me_minor': debtOwedToMe,
      'subscriptions_monthly_minor': subsMonthly,
      'savings_total_minor': savingsTotal,
    };
  }

  Future<List<Map<String, Object?>>> ledger({int limit = 40}) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT id, 'EXPENSE' AS kind, description AS title, amount_minor, currency,
             occurred_at AS at, account_id
      FROM expenses
      UNION ALL
      SELECT id, 'INCOME' AS kind, source AS title, amount_minor, currency,
             occurred_at AS at, account_id
      FROM income
      ORDER BY at DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  Future<void> payDebtFromAccount({
    required String debtId,
    required double amountMajor,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [debtId], limit: 1);
    if (rows.isEmpty) return;
    final prevRem = (rows.first['remaining_amount_minor'] as int?) ?? 0;
    final remaining = prevRem - minor;
    final direction = rows.first['direction'] as String?;
    final title = rows.first['title'] as String? ?? 'Debt';

    await _db.txn((txn) async {
      final ledgerId = AppDatabase.newId();
      String? expenseId;
      if (direction == 'OWED_BY_ME') {
        expenseId = ledgerId;
        await txn.insert('expenses', {
          'id': expenseId,
          'owner_id': ownerId,
          'account_id': accountId,
          'description': 'Debt payment: $title',
          'amount_minor': minor,
          'currency': Defaults.currency,
          'occurred_at': now,
          'payment_method': 'DEBT',
          'created_at': now,
          'updated_at': now,
        });
        await _debitAccount(txn, accountId, minor, now);
      } else {
        await txn.insert('income', {
          'id': ledgerId,
          'owner_id': ownerId,
          'account_id': accountId,
          'source': 'Debt received: $title',
          'amount_minor': minor,
          'currency': Defaults.currency,
          'occurred_at': now,
          'created_at': now,
          'updated_at': now,
        });
        await _creditAccount(txn, accountId, minor, now);
      }

      await txn.insert('debt_payments', {
        'id': AppDatabase.newId(),
        'debt_id': debtId,
        'amount_minor': minor,
        'occurred_at': now,
        'account_id': accountId,
        'expense_id': expenseId,
        'created_at': now,
      });

      await txn.update(
        'debts',
        {
          'remaining_amount_minor': remaining < 0 ? 0 : remaining,
          'status': remaining <= 0 ? 'PAID' : 'OPEN',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );

      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'DEBT_PAYMENT_RECORDED',
        'entity_type': 'DEBT',
        'entity_id': debtId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata':
            '{"amount":$minor,"remaining":${remaining < 0 ? 0 : remaining},"accountId":"${accountId ?? ''}"}',
      });
    });
  }

  Future<void> contributeSavingsFromAccount({
    required String goalId,
    required double amountMajor,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) return;
    final current = ((rows.first['current_amount_minor'] as int?) ?? 0) + minor;
    final target = (rows.first['target_amount_minor'] as int?) ?? 0;
    final name = rows.first['name'] as String? ?? 'Savings';
    final reached = target > 0 && current >= target;

    await _db.txn((txn) async {
      final expenseId = AppDatabase.newId();
      await txn.insert('expenses', {
        'id': expenseId,
        'owner_id': ownerId,
        'account_id': accountId,
        'description': 'Savings: $name',
        'amount_minor': minor,
        'currency': Defaults.currency,
        'occurred_at': now,
        'payment_method': 'SAVINGS',
        'created_at': now,
        'updated_at': now,
      });
      await _debitAccount(txn, accountId, minor, now);

      await txn.insert('savings_contributions', {
        'id': AppDatabase.newId(),
        'goal_id': goalId,
        'amount_minor': minor,
        'occurred_at': now,
        'account_id': accountId,
        'expense_id': expenseId,
        'created_at': now,
      });
      await txn.update(
        'savings_goals',
        {
          'current_amount_minor': current,
          if (reached) 'status': 'REACHED',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': reached ? 'SAVINGS_GOAL_REACHED' : 'SAVINGS_CONTRIBUTION_RECORDED',
        'entity_type': 'SAVINGS_GOAL',
        'entity_id': goalId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"amount":$minor,"current":$current,"target":$target}',
      });
    });
  }

  Future<String> createSubscription({
    required String name,
    required double amountMajor,
    String frequency = 'MONTHLY',
    int daysToRenewal = 30,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final renewal = now + Duration(days: daysToRenewal).inMilliseconds;
    final minor = (amountMajor * 100).round();

    await _db.txn((txn) async {
      await txn.insert('subscriptions', {
        'id': id,
        'owner_id': ownerId,
        'service_name': name,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'status': 'ACTIVE',
        'frequency': frequency,
        'next_renewal_at': renewal,
        'default_account_id': accountId,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('reminders', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'title': 'Subscription renews: $name',
        'message': 'Renewal due — ${Defaults.currency} ${(minor / 100).toStringAsFixed(0)}',
        'trigger_at': renewal - const Duration(days: 1).inMilliseconds,
        'source_type': 'SUBSCRIPTION',
        'source_id': id,
        'status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SUBSCRIPTION_CREATED',
        'entity_type': 'SUBSCRIPTION',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return id;
  }

  Future<void> paySubscription({
    required String subscriptionId,
    double? amountMajor,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query('subscriptions', where: 'id = ?', whereArgs: [subscriptionId], limit: 1);
    if (rows.isEmpty) return;
    final s = rows.first;
    final name = s['service_name'] as String? ?? 'Subscription';
    final minor = amountMajor != null
        ? (amountMajor * 100).round()
        : ((s['amount_minor'] as int?) ?? 0);
    final account = accountId ?? s['default_account_id'] as String?;
    final rule = DomainRecurrence.ruleFromScheduleMap(
      s,
      fallbackStart: DateTime.fromMillisecondsSinceEpoch(now),
    );
    final next = DomainRecurrence.nextAfterMs(rule, now) ??
        DomainRecurrence.nextDueFromLegacy(
          fromMs: now,
          frequency: '${s['frequency'] ?? 'MONTHLY'}',
          monthDay: DateTime.now().day,
        );

    await _db.txn((txn) async {
      final expenseId = AppDatabase.newId();
      await txn.insert('expenses', {
        'id': expenseId,
        'owner_id': ownerId,
        'account_id': account,
        'description': 'Subscription: $name',
        'amount_minor': minor,
        'currency': Defaults.currency,
        'occurred_at': now,
        'payment_method': 'SUBSCRIPTION',
        'created_at': now,
        'updated_at': now,
      });
      await _debitAccount(txn, account, minor, now);

      await txn.update(
        'subscriptions',
        {
          'next_renewal_at': next,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [subscriptionId],
      );

      try {
        await txn.update(
          'reminders',
          {'status': 'CANCELLED', 'updated_at': now},
          where: "source_type = ? AND source_id = ? AND status = 'PENDING'",
          whereArgs: ['SUBSCRIPTION', subscriptionId],
        );
      } catch (_) {}

      await txn.insert('reminders', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'title': 'Subscription renews: $name',
        'message': 'Next renewal',
        'trigger_at': next - const Duration(days: 1).inMilliseconds,
        'source_type': 'SUBSCRIPTION',
        'source_id': subscriptionId,
        'status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SUBSCRIPTION_PAID',
        'entity_type': 'SUBSCRIPTION',
        'entity_id': subscriptionId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"amount":$minor,"expenseId":"$expenseId","nextRenewal":$next}',
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'EXPENSE_RECORDED',
        'entity_type': 'EXPENSE',
        'entity_id': expenseId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> _debitAccount(dynamic txn, String? accountId, int minor, int now) async {
    if (accountId == null) return;
    final ar = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (ar.isEmpty) return;
    final bal = ((ar.first['current_balance_minor'] as int?) ?? 0) - minor;
    await txn.update(
      'financial_accounts',
      {'current_balance_minor': bal, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> _creditAccount(dynamic txn, String? accountId, int minor, int now) async {
    if (accountId == null) return;
    final ar = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (ar.isEmpty) return;
    final bal = ((ar.first['current_balance_minor'] as int?) ?? 0) + minor;
    await txn.update(
      'financial_accounts',
      {'current_balance_minor': bal, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }
}
