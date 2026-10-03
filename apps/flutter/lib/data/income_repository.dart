import '../domain/enums.dart';
import '../services/user_prefs.dart';
import '../domain/models.dart';
import 'database.dart';

class IncomeRepository {
  IncomeRepository(this._db);
  final AppDatabase _db;

  Future<List<Income>> listRecent({int limit = 40}) async {
    final db = await _db.database;
    final rows = await db.query('income', orderBy: 'occurred_at DESC', limit: limit);
    return rows.map(Income.fromMap).toList();
  }

  Future<Income> create({
    required String source,
    required double amountMajor,
    String? accountId,
    String? currency,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = (amountMajor * 100).round();
    final cur = currency ?? UserPrefs.instance.currency;
    await (await _db.database).insert('income', {
      'id': id,
      'owner_id': ownerId,
      'account_id': accountId,
      'source': source,
      'amount_minor': minor,
      'currency': cur,
      'occurred_at': now,
      'created_at': now,
      'updated_at': now,
    });
    if (accountId != null) {
      final rows = await (await _db.database).query(
        'financial_accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final bal = (rows.first['current_balance_minor'] as int?) ?? 0;
        await (await _db.database).update(
          'financial_accounts',
          {'current_balance_minor': bal + minor, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }
    }
    await (await _db.database).insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'INCOME_RECORDED',
      'entity_type': 'INCOME',
      'entity_id': id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': '{"amount":$minor,"currency":"$cur"}',
    });
    return Income(
      id: id,
      ownerId: ownerId,
      source: source,
      amountMinor: minor,
      currency: cur,
      occurredAt: now,
    );
  }

  Future<int> totalMinorThisMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS t FROM income WHERE occurred_at >= ?',
      [start],
    );
    return (rows.first['t'] as int?) ?? 0;
  }
}
