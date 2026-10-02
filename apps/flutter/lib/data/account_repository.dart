import '../domain/enums.dart';
import 'database.dart';

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> list() async {
    final db = await _db.database;
    return db.query('financial_accounts', orderBy: 'name ASC');
  }

  Future<void> create({
    required String name,
    required String type,
    double? balanceMajor,
    String? institution,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('financial_accounts', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'type': type,
      'currency': Defaults.currency,
      'current_balance_minor': balanceMajor == null ? null : (balanceMajor * 100).round(),
      'institution': institution,
      'is_tracked': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> setBalance(String id, double balanceMajor) async {
    final db = await _db.database;
    await db.update(
      'financial_accounts',
      {
        'current_balance_minor': (balanceMajor * 100).round(),
        'updated_at': AppDatabase.nowMs(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
