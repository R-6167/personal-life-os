import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/enums.dart';
import 'database.dart';

/// People, calendar, debt, savings, practical, shopping, categories, search, import.
class ExtendedRepository {
  ExtendedRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listPeople() async {
    final db = await _db.database;
    return db.query('people', where: 'archived_at IS NULL', orderBy: 'name ASC');
  }

  Future<void> addPerson(String name, {String? phone}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('people', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'phone': phone,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listEventsToday() async {
    final db = await _db.database;
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    return db.query(
      'calendar_events',
      where: 'start_at <= ? AND end_at >= ? AND status != ?',
      whereArgs: [end, start, 'CANCELLED'],
      orderBy: 'start_at ASC',
    );
  }

  Future<void> addEvent({required String title, int? hoursFromNow}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final start = now + Duration(hours: hoursFromNow ?? 1).inMilliseconds;
    final end = start + const Duration(hours: 1).inMilliseconds;
    await _db.txn((txn) async {
      final id = AppDatabase.newId();
      await txn.insert('calendar_events', {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'start_at': start,
        'end_at': end,
        'status': 'SCHEDULED',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'EVENT_CREATED',
        'entity_type': 'CALENDAR_EVENT',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> listPendingReminders() async {
    final db = await _db.database;
    return db.query(
      'reminders',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'trigger_at ASC',
    );
  }

  Future<void> addReminder(String title, {int daysAhead = 1}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final trigger = now + Duration(days: daysAhead).inMilliseconds;
    await (await _db.database).insert('reminders', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'trigger_at': trigger,
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> addDependency({required String taskId, required String dependsOnTaskId}) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('task_dependencies', {
      'id': AppDatabase.newId(),
      'task_id': taskId,
      'depends_on_task_id': dependsOnTaskId,
      'type': 'BLOCKED_BY',
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listSubscriptions() async {
    final db = await _db.database;
    return db.query('subscriptions', where: 'status = ?', whereArgs: ['ACTIVE'], orderBy: 'next_renewal_at ASC');
  }

  Future<void> addSubscription(String name, double amountMajor, {int daysToRenewal = 30}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _db.txn((txn) async {
      final id = AppDatabase.newId();
      await txn.insert('subscriptions', {
        'id': id,
        'owner_id': ownerId,
        'service_name': name,
        'amount_minor': (amountMajor * 100).round(),
        'currency': Defaults.currency,
        'billing_frequency': 'MONTHLY',
        'next_renewal_at': now + Duration(days: daysToRenewal).inMilliseconds,
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SUBSCRIPTION_CREATED',
        'entity_type': 'SUBSCRIPTION',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> listDebts() async {
    final db = await _db.database;
    return db.query('debts', where: 'status != ?', whereArgs: ['PAID'], orderBy: 'due_at ASC');
  }

  Future<void> addDebt({required String title, required double amountMajor, required String direction}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    await _db.txn((txn) async {
      final id = AppDatabase.newId();
      await txn.insert('debts', {
        'id': id,
        'owner_id': ownerId,
        'direction': direction,
        'title': title,
        'original_amount_minor': minor,
        'remaining_amount_minor': minor,
        'currency': Defaults.currency,
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'DEBT_CREATED',
        'entity_type': 'DEBT',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> payDebt(String debtId, double amountMajor) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [debtId], limit: 1);
    if (rows.isEmpty) return;
    final remaining = (rows.first['remaining_amount_minor'] as int) - minor;
    await _db.txn((txn) async {
      await txn.insert('debt_payments', {
        'id': AppDatabase.newId(),
        'debt_id': debtId,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'paid_at': now,
        'created_at': now,
      });
      await txn.update(
        'debts',
        {
          'remaining_amount_minor': remaining < 0 ? 0 : remaining,
          'status': remaining <= 0 ? 'PAID' : 'ACTIVE',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'DEBT_PAYMENT_RECORDED',
        'entity_type': 'DEBT',
        'entity_id': debtId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"amount":$minor}',
      });
    });
  }

  Future<List<Map<String, Object?>>> listSavings() async {
    final db = await _db.database;
    return db.query('savings_goals', where: 'status = ?', whereArgs: ['ACTIVE']);
  }

  Future<void> addSavingsGoal(String name, double targetMajor) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('savings_goals', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'target_amount_minor': (targetMajor * 100).round(),
      'currency': Defaults.currency,
      'current_amount_minor': 0,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> contributeSavings(String goalId, double amountMajor) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) return;
    final current = (rows.first['current_amount_minor'] as int) + minor;
    await _db.txn((txn) async {
      await txn.insert('savings_contributions', {
        'id': AppDatabase.newId(),
        'savings_goal_id': goalId,
        'amount_minor': minor,
        'currency': Defaults.currency,
        'occurred_at': now,
        'created_at': now,
      });
      await txn.update(
        'savings_goals',
        {'current_amount_minor': current, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SAVINGS_CONTRIBUTION_RECORDED',
        'entity_type': 'SAVINGS_GOAL',
        'entity_id': goalId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> listPractical() async {
    final db = await _db.database;
    return db.query('practical_items', where: 'archived_at IS NULL', orderBy: 'due_at ASC');
  }

  Future<void> addPractical(String title, {String type = 'OTHER'}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('practical_items', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'type': type,
      'title': title,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listDocuments() async {
    final db = await _db.database;
    return db.query('documents', orderBy: 'expires_at ASC');
  }

  Future<void> addDocument(String title, {String type = 'OTHER'}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _db.txn((txn) async {
      final id = AppDatabase.newId();
      await txn.insert('documents', {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'document_type': type,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'DOCUMENT_CREATED',
        'entity_type': 'DOCUMENT',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> listShoppingLists() async {
    final db = await _db.database;
    return db.query('shopping_lists', where: 'status != ?', whereArgs: ['COMPLETED']);
  }

  Future<void> addShoppingList(String name) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('shopping_lists', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'status': 'ACTIVE',
      'created_at': now,
    });
  }

  Future<void> addShoppingItem(String listId, String name) async {
    await (await _db.database).insert('shopping_items', {
      'id': AppDatabase.newId(),
      'shopping_list_id': listId,
      'name': name,
      'purchased': 0,
    });
  }

  Future<List<Map<String, String>>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final q = '%${query.trim()}%';
    final db = await _db.database;
    final results = <Map<String, String>>[];

    Future<void> scan(String table, String titleCol, String type) async {
      try {
        final rows = await db.query(table, where: '$titleCol LIKE ?', whereArgs: [q], limit: 10);
        for (final r in rows) {
          results.add({'type': type, 'title': '${r[titleCol]}', 'id': '${r['id']}'});
        }
      } catch (_) {}
    }

    await scan('tasks', 'title', 'TASK');
    await scan('projects', 'title', 'PROJECT');
    await scan('goals', 'title', 'GOAL');
    await scan('notes', 'content', 'NOTE');
    await scan('bills', 'name', 'BILL');
    await scan('people', 'name', 'PERSON');
    await scan('expenses', 'description', 'EXPENSE');
    return results;
  }

  Future<int> importBackupJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) return 0;
    final map = Map<String, dynamic>.from(decoded);
    var count = 0;
    final tables = [
      'goals', 'projects', 'tasks', 'habits', 'notes', 'bills', 'expenses', 'income',
      'people', 'routines', 'subscriptions', 'debts', 'savings_goals', 'practical_items',
    ];
    await _db.txn((txn) async {
      for (final table in tables) {
        final rows = map[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) continue;
          final snake = <String, Object?>{};
          row.forEach((k, v) {
            snake[_toSnake('$k')] = v;
          });
          if (snake['id'] == null) continue;
          try {
            await txn.insert(table, snake, conflictAlgorithm: ConflictAlgorithm.ignore);
            count++;
          } catch (_) {}
        }
      }
    });
    return count;
  }

  String _toSnake(String camel) {
    return camel.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  }
}
