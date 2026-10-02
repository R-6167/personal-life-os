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

  /// [amountMajor] e.g. 150.50 KES → stored as 15050 minor units.
  Future<Expense> create({equired String description, required double amountMajor, String? merchant}) async {
    final db = await _db.database;
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
      merchant: merchant,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('expenses', expense.toInsertMap());
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'EXPENSE_RECORDED',
      'entity_type': 'EXPENSE',
      'entity_id': expense.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': '{"amount":$minor,"currency":"${Defaults.currency}"}',
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
}
