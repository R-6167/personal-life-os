import '../domain/enums.dart';
import '../services/user_prefs.dart';
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
    String? categoryId,
    String? accountId,
    String? currency,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = (amountMajor * 100).round();
    final cur = currency ?? UserPrefs.instance.currency;
    await (await _db.database).insert('expenses', {
      'id': id,
      'owner_id': ownerId,
      'account_id': accountId,
      'description': description,
      'amount_minor': minor,
      'currency': cur,
      'occurred_at': now,
      'category_id': categoryId,
      'created_at': now,
      'updated_at': now,
    });
    await (await _db.database).insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'EXPENSE_RECORDED',
      'entity_type': 'EXPENSE',
      'entity_id': id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': '{"amount":$minor,"currency":"$cur"}',
    });
    return Expense(
      id: id,
      ownerId: ownerId,
      description: description,
      amountMinor: minor,
      currency: cur,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> totalMinorThisMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS t FROM expenses WHERE occurred_at >= ?',
      [start],
    );
    return (rows.first['t'] as int?) ?? 0;
  }
}
