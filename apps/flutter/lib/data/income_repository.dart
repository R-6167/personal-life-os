import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class IncomeRepository {
  IncomeRepository(this._db);
  final AppDatabase _db;

  Future<List<Income>> listRecent({int limit = 30}) async {
    final db = await _db.database;
    final rows = await db.query('income', orderBy: 'occurred_at DESC', limit: limit);
    return rows.map(Income.fromMap).toList();
  }

  Future<Income> create({required String source, required double amountMajor, String? accountId}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final id = AppDatabase.newId();
    await _db.txn((txn) async {
      await txn.insert('income', {
        'id': id,
        'owner_id': ownerId,
        'account_id': accountId,
        'source': source,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'occurred_at': now,
        'created_at': now,
        'updated_at': now,
      });
      if (accountId != null) {
        final rows = await txn.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
        if (rows.isNotEmpty && rows.first['current_balance_minor'] != null) {
          final bal = (rows.first['current_balance_minor'] as int) + minor;
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
        'event_type': 'INCOME_RECORDED',
        'entity_type': 'INCOME',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"amount":$minor,"currency":"${Defaults.currency}"${accountId != null ? ',"accountId":"$accountId"' : ''}}',
      });
    });
    return Income(
      id: id,
      ownerId: ownerId,
      source: source,
      amountMinor: minor,
      currency: Defaults.currency,
      occurredAt: now,
    );
  }

  Future<int> totalMinorThisMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM income WHERE occurred_at >= ?',
      [start],
    );
    return (rows.first['s'] as int?) ?? 0;
  }
}
