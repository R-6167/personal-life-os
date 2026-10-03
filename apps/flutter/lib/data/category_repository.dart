import '../domain/enums.dart';
import 'database.dart';

/// Expense/income categories used by budgets and expense forms.
class CategoryRepository {
  CategoryRepository(this._db);
  final AppDatabase _db;

  static const defaultExpenseNames = [
    'Food',
    'Transport',
    'Housing',
    'Utilities',
    'Health',
    'Entertainment',
    'Shopping',
    'Education',
    'Personal',
    'Other',
  ];

  Future<List<Map<String, Object?>>> listExpense() async {
    await ensureDefaults();
    final ownerId = await _db.requireOwnerId();
    return (await _db.database).query(
      'categories',
      where: '(owner_id = ? OR owner_id IS NULL) AND type = ?',
      whereArgs: [ownerId, 'EXPENSE'],
      orderBy: 'name ASC',
    );
  }

  Future<void> ensureDefaults() async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final existing = await db.query(
      'categories',
      where: 'owner_id = ? AND type = ?',
      whereArgs: [ownerId, 'EXPENSE'],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = AppDatabase.nowMs();
    for (final name in defaultExpenseNames) {
      await db.insert('categories', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'name': name,
        'type': 'EXPENSE',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<String> createExpense(String name) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('categories', {
      'id': id,
      'owner_id': ownerId,
      'name': name.trim(),
      'type': 'EXPENSE',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await (await _db.database).query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
