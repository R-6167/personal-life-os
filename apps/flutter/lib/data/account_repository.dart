import '../domain/enums.dart';
import 'database.dart';

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> list() async {
    final db = await _db.database;
    return db.query('financial_accounts', orderBy: 'name ASC');
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await (await _db.database).query(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> create({
    required String name,
    required String type,
    double? balanceMajor,
    String? currency,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = balanceMajor == null ? 0 : (balanceMajor * 100).round();
    await (await _db.database).insert('financial_accounts', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'type': type,
      'currency': currency ?? Defaults.currency,
      'current_balance_minor': minor,
      'is_tracked': 1,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> adjustBalance({
    required String accountId,
    required double deltaMajor,
  }) async {
    await applyDeltaMinor(accountId: accountId, deltaMinor: (deltaMajor * 100).round());
  }

  /// Signed minor units: negative = debit (expense/payment), positive = credit (income).
  Future<void> applyDeltaMinor({equired String accountId, required int deltaMinor}) async {
    final db = await _db.database;
    final rows = await db.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) return;
    final current = (rows.first['current_balance_minor'] as int?) ?? 0;
    await db.update(
      'financial_accounts',
      {
        'current_balance_minor': current + deltaMinor,
        'updated_at': AppDatabase.nowMs(),
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<int> totalBalanceMinor() async {
    final rows = await list();
    var sum = 0;
    for (final r in rows) {
      if ((r['is_tracked'] as int?) == 0) continue;
      sum += (r['current_balance_minor'] as int?) ?? 0;
    }
    return sum;
  }
}
