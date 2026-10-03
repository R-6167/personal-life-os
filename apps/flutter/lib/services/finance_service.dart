import '../data/account_repository.dart';
import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/income_repository.dart';
import '../domain/enums.dart';

/// Connected financial operations and cash-flow views.
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
    return {
      'income_minor': inMinor,
      'expense_minor': outMinor,
      'net_minor': inMinor - outMinor,
      'accounts_balance_minor': bal,
      'bills_open_minor': billsDueMinor,
      'debt_owed_by_me_minor': debtOwedByMe,
      'debt_owed_to_me_minor': debtOwedToMe,
      'subscriptions_monthly_minor': subsMonthly,
    };
  }

  /// Unified recent financial history for reconciliation.
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
    final remaining = ((rows.first['remaining_amount_minor'] as int?) ?? 0) - minor;
    final direction = rows.first['direction'] as String?;
    final title = rows.first['title'] as String? ?? 'Debt';

    await _db.txn((txn) async {
      final expenseId = AppDatabase.newId();
      if (direction == 'OWED_BY_ME') {
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
        if (accountId != null) {
          final ar = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
          if (ar.isNotEmpty) {
            final bal = ((ar.first['current_balance_minor'] as int?) ?? 0) - minor;
            await txn.update(
              'financial_accounts',
              {'current_balance_minor': bal, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          }
        }
      } else {
        // Money received
        await txn.insert('income', {
          'id': expenseId,
          'owner_id': ownerId,
          'account_id': accountId,
          'source': 'Debt received: $title',
          'amount_minor': minor,
          'currency': Defaults.currency,
          'occurred_at': now,
          'created_at': now,
          'updated_at': now,
        });
        if (accountId != null) {
          final ar = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
          if (ar.isNotEmpty) {
            final bal = ((ar.first['current_balance_minor'] as int?) ?? 0) + minor;
            await txn.update(
              'financial_accounts',
              {'current_balance_minor': bal, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          }
        }
      }

      await txn.insert('debt_payments', {
        'id': AppDatabase.newId(),
        'debt_id': debtId,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'paid_at': now,
        'account_id': accountId,
        'expense_id': direction == 'OWED_BY_ME' ? expenseId : null,
        'income_id': direction == 'OWED_BY_ME' ? null : expenseId,
        'created_at': now,
      });

      await txn.update(
        'debts',
        {
          'remaining_amount_minor': remaining < 0 ? 0 : remaining,
          'status': remaining <= 0 ? 'PAID' : 'ACTIVE',
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
        'metadata': '{"amount":$minor,"accountId":"${accountId ?? ''}"}',
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
    final name = rows.first['name'] as String? ?? 'Savings';

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
      if (accountId != null) {
        final ar = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
        if (ar.isNotEmpty) {
          final bal = ((ar.first['current_balance_minor'] as int?) ?? 0) - minor;
          await txn.update(
            'financial_accounts',
            {'current_balance_minor': bal, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [accountId],
          );
        }
      }
      await txn.insert('savings_contributions', {
        'id': AppDatabase.newId(),
        'savings_goal_id': goalId,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'account_id': accountId,
        'occurred_at': now,
        'created_at': now,
      });
      await txn.update(
        'savings_goals',
        {'current_amount_minor': current, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SAVINGS_CONTRIBUTION_RECORDED',
        'entity_type': 'SAVINGS_GOAL',
        'entity_id': goalId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
