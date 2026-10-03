import '../domain/enums.dart';
import '../services/user_prefs.dart';
import 'database.dart';

enum BudgetAlertLevel { ok, near, exceeded }

class BudgetStatus {
  BudgetStatus({
    required this.id,
    required this.name,
    required this.limitMinor,
    required this.spentMinor,
    required this.level,
    this.categoryId,
    this.categoryName,
    this.scopeLabel = '',
  });

  final String id;
  final String name;
  final int limitMinor;
  final int spentMinor;
  final BudgetAlertLevel level;
  final String? categoryId;
  final String? categoryName;
  final String scopeLabel;
}

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listActive() async {
    final db = await _db.database;
    return db.query('budgets', where: "status = 'ACTIVE'", orderBy: 'name ASC');
  }

  Future<String> create({
    required String name,
    required double amountMajor,
    String? categoryId,
    String? matchKey,
    double alertThreshold = 0.8,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('budgets', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'match_key': matchKey,
      'category_id': categoryId,
      'amount_minor': (amountMajor * 100).round(),
      'period': 'MONTHLY',
      'alert_threshold': alertThreshold,
      'currency': UserPrefs.instance.currency,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<int> getMonthlySpend({String? categoryId, String? matchKey}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    if (categoryId != null) {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor),0) AS t FROM expenses WHERE occurred_at >= ? AND category_id = ?',
        [start, categoryId],
      );
      return (rows.first['t'] as int?) ?? 0;
    }
    if (matchKey != null && matchKey.isNotEmpty) {
      final rows = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_minor),0) AS t FROM expenses WHERE occurred_at >= ? AND (description LIKE ? OR merchant LIKE ?)",
        [start, '%$matchKey%', '%$matchKey%'],
      );
      return (rows.first['t'] as int?) ?? 0;
    }
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor),0) AS t FROM expenses WHERE occurred_at >= ?',
      [start],
    );
    return (rows.first['t'] as int?) ?? 0;
  }

  Future<List<BudgetStatus>> statuses() async {
    final budgets = await listActive();
    final out = <BudgetStatus>[];
    for (final b in budgets) {
      final limit = (b['amount_minor'] as int?) ?? 0;
      final catId = b['category_id'] as String?;
      final match = b['match_key'] as String?;
      final spent = await getMonthlySpend(categoryId: catId, matchKey: match);
      final thr = (b['alert_threshold'] as num?)?.toDouble() ?? 0.8;
      BudgetAlertLevel level = BudgetAlertLevel.ok;
      if (limit > 0) {
        final ratio = spent / limit;
        if (ratio >= 1) {
          level = BudgetAlertLevel.exceeded;
        } else if (ratio >= thr) {
          level = BudgetAlertLevel.near;
        }
      }
      out.add(BudgetStatus(
        id: b['id'] as String,
        name: b['name'] as String,
        limitMinor: limit,
        spentMinor: spent,
        level: level,
        categoryId: catId,
        scopeLabel: match ?? catId ?? 'all',
      ));
    }
    return out;
  }

  Future<List<BudgetStatus>> alerts() async {
    final all = await statuses();
    return all.where((s) => s.level != BudgetAlertLevel.ok).toList();
  }
}
