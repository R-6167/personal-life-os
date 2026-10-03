import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);
  final AppDatabase _db;

  Future<List<Expense>> listRecent({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense> create({
    required String description,
    required double amountMajor,
    String? merchant,
    String? accountId,
    String? categoryId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final expense = Expense(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      description: description,
      amountMinor: minor,
      currency: Defaults.currency,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = expense.toInsertMap();
      if (accountId != null) map['account_id'] = accountId;
      if (merchant != null) map['merchant'] = merchant;
      if (categoryId != null) map['category_id'] = categoryId;
      await txn.insert('expenses', map);
      if (accountId != null) {
        final rows = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
        if (rows.isNotEmpty && rows.first['current_balance_minor'] != null) {
          final bal = (rows.first['current_balance_minor'] as int) - minor;
          await txn.update(
            'financial_accounts',
            {'current_balance_minor': bal, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [accountId],
          );
        }
      }
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'EXPENSE_RECORDED',
        'entity_type': 'EXPENSE',
        'entity_id': expense.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata':
            '{"amount":$minor,"currency":"${Defaults.currency}"${accountId != null ? ',"accountId":"$accountId"' : ''}${categoryId != null ? ',"categoryId":"$categoryId"' : ''}}',
      });
    });
    return expense;
  }

  Future<int> totalMinorThisMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses WHERE occurred_at >= ?',
      [start],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> totalMinorThisMonthForCategory(String categoryId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses WHERE occurred_at >= ? AND category_id = ?',
      [start, categoryId],
    );
    return (result.first['total'] as int?) ?? 0;
  }
}
