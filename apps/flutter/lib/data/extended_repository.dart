import '../domain/enums.dart';
import 'database.dart';

/// People, calendar, debt, savings, practical, shopping, search.
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
    // status column may be absent on older DBs — tolerate either shape
    try {
      return await db.query(
        'calendar_events',
        where: 'start_at <= ? AND (end_at IS NULL OR end_at >= ?) AND (status IS NULL OR status != ?)',
        whereArgs: [end, start, 'CANCELLED'],
        orderBy: 'start_at ASC',
      );
    } catch (_) {
      return db.query(
        'calendar_events',
        where: 'start_at <= ? AND (end_at IS NULL OR end_at >= ?)',
        whereArgs: [end, start],
        orderBy: 'start_at ASC',
      );
    }
  }

  Future<List<Map<String, Object?>>> listUpcomingAppointments({int days = 7}) async {
    final now = AppDatabase.nowMs();
    final end = now + Duration(days: days).inMilliseconds;
    try {
      return await (await _db.database).query(
        'calendar_events',
        where: 'start_at >= ? AND start_at <= ? AND (status IS NULL OR status != ?)',
        whereArgs: [now, end, 'CANCELLED'],
        orderBy: 'start_at ASC',
      );
    } catch (_) {
      return (await _db.database).query(
        'calendar_events',
        where: 'start_at >= ? AND start_at <= ?',
        whereArgs: [now, end],
        orderBy: 'start_at ASC',
      );
    }
  }

  Future<void> addEvent({required String title, int? hoursFromNow}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final start = now + Duration(hours: hoursFromNow ?? 1).inMilliseconds;
    final end = start + const Duration(hours: 1).inMilliseconds;
    await (await _db.database).insert('calendar_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'start_at': start,
      'end_at': end,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> addCalendarEvent({
    required String title,
    required DateTime start,
    DateTime? end,
    String? location,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('calendar_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'start_at': start.millisecondsSinceEpoch,
      'end_at': (end ?? start.add(const Duration(hours: 1))).millisecondsSinceEpoch,
      'location': location,
      'created_at': now,
      'updated_at': now,
    });
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

  Future<void> addReminderAt({
    required String title,
    required DateTime triggerAt,
    String? message,
    String? sourceType,
    String? sourceId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('reminders', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'message': message,
      'trigger_at': triggerAt.millisecondsSinceEpoch,
      'source_type': sourceType,
      'source_id': sourceId,
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listPendingReminders() async {
    return (await _db.database).query(
      'reminders',
      where: "status = 'PENDING'",
      orderBy: 'trigger_at ASC',
    );
  }

  Future<void> completeReminder(String id) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'reminders',
      {'status': 'COMPLETED', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> snoozeReminder(String id, {int minutes = 30}) async {
    final now = AppDatabase.nowMs();
    final rows = await (await _db.database).query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final trigger = (rows.first['trigger_at'] as int?) ?? now;
    final next = (trigger < now ? now : trigger) + minutes * 60 * 1000;
    await (await _db.database).update(
      'reminders',
      {'trigger_at': next, 'status': 'PENDING', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addDependency({
    required String taskId,
    required String dependsOnTaskId,
  }) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('task_dependencies', {
      'id': AppDatabase.newId(),
      'task_id': taskId,
      'depends_on_task_id': dependsOnTaskId,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listSubscriptions() async {
    return (await _db.database).query(
      'subscriptions',
      where: "status = 'ACTIVE'",
      orderBy: 'service_name ASC',
    );
  }

  Future<void> addSubscription(String name, double amountMajor, {int daysToRenewal = 30}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    // Schema columns only: service_name (not name), amount_minor, currency, status
    await (await _db.database).insert('subscriptions', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'service_name': name,
      'amount_minor': (amountMajor * 100).round(),
      'currency': Defaults.currency,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listDebts() async {
    return (await _db.database).query(
      'debts',
      where: "status = 'OPEN' OR status = 'ACTIVE'",
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> addDebt({
    required String title,
    required double amountMajor,
    required String direction,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    // No counterparty column in schema
    await (await _db.database).insert('debts', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'direction': direction,
      'original_amount_minor': minor,
      'remaining_amount_minor': minor,
      'currency': Defaults.currency,
      'status': 'OPEN',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> payDebt(String debtId, double amountMajor) async {
    final db = await _db.database;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [debtId], limit: 1);
    if (rows.isEmpty) return;
    final remaining = (rows.first['remaining_amount_minor'] as int?) ?? 0;
    final pay = (amountMajor * 100).round();
    final next = (remaining - pay).clamp(0, remaining);
    final now = AppDatabase.nowMs();
    await db.update(
      'debts',
      {
        'remaining_amount_minor': next,
        'status': next == 0 ? 'PAID' : 'OPEN',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [debtId],
    );
    await db.insert('debt_payments', {
      'id': AppDatabase.newId(),
      'debt_id': debtId,
      'amount_minor': pay,
      'occurred_at': now,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listSavings() async {
    return (await _db.database).query(
      'savings_goals',
      where: "status = 'ACTIVE'",
      orderBy: 'name ASC',
    );
  }

  Future<void> addSavingsGoal(String name, double targetMajor) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('savings_goals', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'target_amount_minor': (targetMajor * 100).round(),
      'current_amount_minor': 0,
      'currency': Defaults.currency,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> contributeSavings(String goalId, double amountMajor) async {
    final db = await _db.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) return;
    final current = (rows.first['current_amount_minor'] as int?) ?? 0;
    final add = (amountMajor * 100).round();
    final now = AppDatabase.nowMs();
    await db.update(
      'savings_goals',
      {
        'current_amount_minor': current + add,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
    await db.insert('savings_contributions', {
      'id': AppDatabase.newId(),
      'goal_id': goalId,
      'amount_minor': add,
      'occurred_at': now,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listPractical() async {
    try {
      return await (await _db.database).query(
        'practical_items',
        where: "status != 'DONE' AND status != 'CANCELLED'",
        orderBy: 'updated_at DESC',
      );
    } catch (_) {
      return (await _db.database).query('practical_items', orderBy: 'updated_at DESC');
    }
  }

  Future<void> addPractical(
    String title, {
    String type = 'OTHER',
    DateTime? dueAt,
    String? notes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    // Schema: title, kind, notes, status — no type/due_at required
    await (await _db.database).insert('practical_items', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'kind': type,
      'notes': notes,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> addVehicleService({
    required String title,
    DateTime? dueAt,
    String? notes,
  }) async {
    await addPractical(title, type: 'VEHICLE', dueAt: dueAt, notes: notes);
  }

  Future<void> completePractical(String id) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'practical_items',
      {'status': 'DONE', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> listDocuments() async {
    return (await _db.database).query('documents', orderBy: 'expires_at ASC');
  }

  Future<void> addDocument(
    String title, {
    String type = 'OTHER',
    DateTime? expiresAt,
    String? documentNumber,
    String? issuer,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('documents', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'notes': [if (documentNumber != null) 'No: $documentNumber', if (issuer != null) 'Issuer: $issuer']
          .where((_) => true)
          .join(' · ')
          .ifEmpty,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listShoppingLists() async {
    try {
      return await (await _db.database).query(
        'shopping_lists',
        where: 'archived_at IS NULL',
        orderBy: 'name ASC',
      );
    } catch (_) {
      return (await _db.database).query('shopping_lists', orderBy: 'name ASC');
    }
  }

  Future<String> addShoppingList(String name) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('shopping_lists', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'status': 'OPEN',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> addShoppingItem(String listId, String name) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('shopping_items', {
      'id': AppDatabase.newId(),
      'list_id': listId,
      'name': name,
      'is_done': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listShoppingItems(String listId) async {
    return (await _db.database).query(
      'shopping_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'is_done ASC, name ASC',
    );
  }

  Future<List<Map<String, Object?>>> search(String query) async {
    final q = '%${query.trim()}%';
    if (query.trim().isEmpty) return [];
    final db = await _db.database;
    final results = <Map<String, Object?>>[];
    for (final row in await db.rawQuery(
      "SELECT id, title AS label, 'TASK' AS kind FROM tasks WHERE title LIKE ? LIMIT 10",
      [q],
    )) {
      results.add(row);
    }
    for (final row in await db.rawQuery(
      "SELECT id, title AS label, 'NOTE' AS kind FROM notes WHERE title LIKE ? LIMIT 10",
      [q],
    )) {
      results.add(row);
    }
    for (final row in await db.rawQuery(
      "SELECT id, name AS label, 'PERSON' AS kind FROM people WHERE name LIKE ? LIMIT 10",
      [q],
    )) {
      results.add(row);
    }
    return results;
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}
