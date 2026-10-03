import '../domain/enums.dart';
import 'database.dart';

enum BudgetAlertLevel { ok, warning, exceeded }

class BudgetStatus {
  BudgetStatus({
    required this.id,
    required this.name,
    required this.limitMinor,
    required this.spentMinor,
    required this.alertThreshold,
    this.matchKey,
    this.categoryId,
    this.categoryName,
  });

  final String id;
  final String name;
  final int limitMinor;
  final int spentMinor;
  final double alertThreshold;
  final String? matchKey;
  final String? categoryId;
  final String? categoryName;

  double get ratio => limitMinor <= 0 ? 0 : spentMinor / limitMinor;

  BudgetAlertLevel get level {
    if (spentMinor >= limitMinor) return BudgetAlertLevel.exceeded;
    if (ratio >= alertThreshold) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.ok;
  }

  int get remainingMinor => (limitMinor - spentMinor).clamp(0, limitMinor);

  String get scopeLabel {
    if (categoryName != null && categoryName!.isNotEmpty) return categoryName!;
    if (matchKey != null && matchKey!.isNotEmpty) return 'match: $matchKey';
    return 'all spend';
  }
}

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listActive() async {
    final ownerId = await _db.requireOwnerId();
    return (await _db.database).query(
      'budgets',
      where: 'owner_id = ? AND status = ?',
      whereArgs: [ownerId, 'ACTIVE'],
      orderBy: 'name ASC',
    );
  }

  Future<void> create({
    required String name,
    required double amountMajor,
    String? matchKey,
    String? categoryId,
    double alertThreshold = 0.8,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = (amountMajor * 100).round();
    await _db.txn((txn) async {
      await txn.insert('budgets', {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'match_key': (matchKey == null || matchKey.trim().isEmpty) ? null : matchKey.trim(),
        'category_id': categoryId,
        'amount_minor': minor,
        'period': 'MONTHLY',
        'alert_threshold': alertThreshold,
        'currency': Defaults.currency,
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'BUDGET_CREATED',
        'entity_type': 'BUDGET',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> delete(String id) async {
    await (await _db.database).update(
      'budgets',
      {'status': 'ARCHIVED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  int _monthStartMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1).millisecondsSinceEpoch;
  }

  /// Spent this month. Priority: category_id → match_key → all expenses.
  Future<int> spentMinorFor(Map<String, Object?> budget) async {
    final db = await _db.database;
    final start = _monthStartMs();
    final categoryId = budget['category_id'] as String?;
    if (categoryId != null && categoryId.isNotEmpty) {
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_minor), 0) AS s FROM expenses
        WHERE occurred_at >= ? AND category_id = ?
        ''',
        [start, categoryId],
      );
      return (rows.first['s'] as int?) ?? 0;
    }
    final key = budget['match_key'] as String?;
    if (key == null || key.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM expenses WHERE occurred_at >= ?',
        [start],
      );
      return (rows.first['s'] as int?) ?? 0;
    }
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS s FROM expenses
      WHERE occurred_at >= ?
        AND (
          LOWER(description) LIKE ?
          OR LOWER(COALESCE(merchant, '')) LIKE ?
        )
      ''',
      [start, '%${key.toLowerCase()}%', '%${key.toLowerCase()}%'],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<List<BudgetStatus>> statuses() async {
    final budgets = await listActive();
    final out = <BudgetStatus>[];
    final db = await _db.database;
    for (final b in budgets) {
      final spent = await spentMinorFor(b);
      String? catName;
      final catId = b['category_id'] as String?;
      if (catId != null) {
        final rows = await db.query('categories', where: 'id = ?', whereArgs: [catId], limit: 1);
        if (rows.isNotEmpty) catName = rows.first['name'] as String?;
      }
      out.add(BudgetStatus(
        id: b['id'] as String,
        name: b['name'] as String,
        limitMinor: (b['amount_minor'] as int?) ?? 0,
        spentMinor: spent,
        alertThreshold: (b['alert_threshold'] as num?)?.toDouble() ?? 0.8,
        matchKey: b['match_key'] as String?,
        categoryId: catId,
        categoryName: catName,
      ));
    }
    return out;
  }

  Future<List<BudgetStatus>> alerts() async {
    final all = await statuses();
    return all.where((s) => s.level != BudgetAlertLevel.ok).toList();
  }
}
