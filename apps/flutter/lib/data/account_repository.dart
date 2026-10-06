import '../domain/db_map.dart';
import '../domain/enums.dart';
import '../services/user_prefs.dart';
import 'atomic_write.dart';
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
    final cur = currency ?? UserPrefs.instance.currency;
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.insert('financial_accounts', {
          'id': id,
          'owner_id': ownerId,
          'name': name,
          'type': type,
          'currency': cur,
          'current_balance_minor': minor,
          'created_at': now,
          'updated_at': now,
        });
      },
      eventType: 'ACCOUNT_CREATED',
      entityType: 'ACCOUNT',
      entityId: id,
      occurredAt: now,
      metadata: '{"balance":$minor,"currency":"$cur"}',
    );
    return id;
  }

  /// Single balance write path used by UI adjustments.
  Future<void> adjustBalance({required String accountId, required double deltaMajor}) async {
    final delta = (deltaMajor * 100).round();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.query(
          'financial_accounts',
          where: 'id = ?',
          whereArgs: [accountId],
          limit: 1,
        );
        if (rows.isEmpty) return;
        final current = dbIntOr(rows.first['current_balance_minor']);
        final next = current + delta;
        await txn.update(
          'financial_accounts',
          {'current_balance_minor': next, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      },
      eventType: 'ACCOUNT_BALANCE_ADJUSTED',
      entityType: 'ACCOUNT',
      entityId: accountId,
      occurredAt: now,
      metadata: '{"delta":$delta}',
    );
  }

  Future<int> totalBalanceMinor() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance_minor), 0) AS t FROM financial_accounts',
    );
    return dbIntOr(rows.first['t']);
  }
}
