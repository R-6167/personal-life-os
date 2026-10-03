import '../domain/enums.dart';
import '../services/user_prefs.dart';
import 'database.dart';

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> list() async {
    final db = await _db.database;
    return db.query('financial_accounts', orderBy: 'name ASC');
  }

  Future<String> create({
    required String name,
    String type = 'OTHER',
    double? balanceMajor,
    String? currency,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = ((balanceMajor ?? 0) * 100).round();
    await (await _db.database).insert('financial_accounts', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'type': type,
      'currency': currency ?? UserPrefs.instance.currency,
      'current_balance_minor': minor,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> adjustBalance({required String accountId, required double deltaMajor}) async {
    final db = await _db.database;
    final rows = await db.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) return;
    final current = (rows.first['current_balance_minor'] as int?) ?? 0;
    final next = current + (deltaMajor * 100).round();
    await db.update(
      'financial_accounts',
      {'current_balance_minor': next, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }
}
