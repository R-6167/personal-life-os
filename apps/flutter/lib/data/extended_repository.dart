import '../domain/enums.dart';
import '../services/domain_recurrence.dart';
import '../services/smart_reminder_service.dart';
import 'database.dart';

/// People, calendar, debt, savings, practical, shopping, search.
class ExtendedRepository {
  ExtendedRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listPeople() async {
    return (await _db.database).query('people', orderBy: 'name ASC');
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
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    return (await _db.database).query(
      'calendar_events',
      where: 'start_at >= ? AND start_at <= ?',
      whereArgs: [start, end],
      orderBy: 'start_at ASC',
    );
  }

  Future<void> addEvent({required String title, int? startAt, int? endAt}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final start = startAt ?? now + const Duration(hours: 2).inMilliseconds;
    final end = endAt ?? start + const Duration(hours: 1).inMilliseconds;
    await (await _db.database).insert('calendar_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'start_at': start,
      'end_at': end,
      'status': 'CONFIRMED',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listReminders() async {
    return (await _db.database).query(
      'reminders',
      where: "status = 'PENDING'",
      orderBy: 'trigger_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> listPendingReminders() async {
    final db = await _db.database;
    return db.query(
      'reminders',
      where: "status = 'PENDING'",
      orderBy: 'trigger_at ASC',
    );
  }

  Future<void> addReminder(String title, {int? triggerAt, String? message}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final at = triggerAt ?? now + const Duration(hours: 1).inMilliseconds;
    await (await _db.database).insert('reminders', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'message': message,
      'trigger_at': at,
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> addReminderAt({required String title, required DateTime triggerAt, String? message}) async {
    await addReminder(title, triggerAt: triggerAt.millisecondsSinceEpoch, message: message);
  }

  Future<void> completeReminder(String id) async {
    await (await _db.database).update(
      'reminders',
      {'status': 'DONE', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelReminder(String id) async {
    await (await _db.database).update(
      'reminders',
      {'status': 'CANCELLED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReminder(String id) => cancelReminder(id);

  Future<void> snoozeReminder(String id, {int minutes = 15}) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final rows = await db.query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final current = rows.first['trigger_at'] as int? ?? now;
    final base = current > now ? current : now;
    await db.update(
      'reminders',
      {
        'trigger_at': base + minutes * 60 * 1000,
        'status': 'PENDING',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> completePractical(String id) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final n = await db.update(
      'practical_items',
      {'status': 'DONE', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n == 0) {
      await db.update(
        'reminders',
        {'status': 'DONE', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<Map<String, Object?>>> listSubscriptions({bool includePaused = true}) async {
    final where = includePaused
        ? "status IN ('ACTIVE', 'PAUSED')"
        : "status = 'ACTIVE'";
    return (await _db.database).query(
      'subscriptions',
      where: where,
      orderBy: "CASE status WHEN 'ACTIVE' THEN 0 WHEN 'PAUSED' THEN 1 ELSE 2 END, service_name ASC",
    );
  }

  Future<void> addSubscription(
    String name,
    double amountMajor, {
    int daysToRenewal = 30,
    String frequency = 'MONTHLY',
    int interval = 1,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final next = now + Duration(days: daysToRenewal).inMilliseconds;
    await (await _db.database).insert('subscriptions', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'service_name': name,
      'amount_minor': (amountMajor * 100).round(),
      'currency': Defaults.currency,
      'frequency': frequency,
      'interval': interval,
      'next_renewal_at': next,
      'default_account_id': accountId,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int?> renewSubscription(String subscriptionId) async {
    final db = await _db.database;
    final rows = await db.query('subscriptions', where: 'id = ?', whereArgs: [subscriptionId], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final frequency = row['frequency'] as String? ?? 'MONTHLY';
    if (!DomainRecurrence.isRecurringFrequency(frequency)) return null;
    final fromMs = (row['next_renewal_at'] as int?) ?? AppDatabase.nowMs();
    final rule = DomainRecurrence.ruleFromScheduleMap(
      row,
      fallbackStart: DateTime.fromMillisecondsSinceEpoch(fromMs),
    );
    final next = DomainRecurrence.nextAfterMs(rule, fromMs);
    if (next == null) return null;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await txn.update(
        'subscriptions',
        {'next_renewal_at': next, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [subscriptionId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'SUBSCRIPTION_RENEWED',
        'entity_type': 'SUBSCRIPTION',
        'entity_id': subscriptionId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"nextRenewal":$next}',
      });
    });
    return next;
  }

  Future<void> pauseSubscription(String id) async {
    await (await _db.database).update(
      'subscriptions',
      {'status': 'PAUSED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelSubscription(String id) async {
    await (await _db.database).update(
      'subscriptions',
      {'status': 'CANCELLED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resumeSubscription(String id) async {
    await (await _db.database).update(
      'subscriptions',
      {'status': 'ACTIVE', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    String direction = 'OWED_BY_ME',
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    await (await _db.database).insert('debts', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'direction': direction,
      'principal_amount_minor': minor,
      'remaining_amount_minor': minor,
      'currency': Defaults.currency,
      'status': 'OPEN',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> payDebt(String debtId, double amountMajor, {String? accountId}) async {
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [debtId], limit: 1);
    if (rows.isEmpty) return;
    final prev = (rows.first['remaining_amount_minor'] as int?) ?? 0;
    final next = (prev - minor).clamp(0, 1 << 30);
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await txn.update(
        'debts',
        {
          'remaining_amount_minor': next,
          'status': next == 0 ? 'PAID' : 'OPEN',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
      await txn.insert('debt_payments', {
        'id': AppDatabase.newId(),
        'debt_id': debtId,
        'amount_minor': minor,
        'occurred_at': now,
        'account_id': accountId,
        'created_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'DEBT_PAYMENT_RECORDED',
        'entity_type': 'DEBT',
        'entity_id': debtId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> listSavings() async {
    return (await _db.database).query(
      'savings_goals',
      where: "status = 'ACTIVE' OR status = 'REACHED'",
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> addSavingsGoal(String name, double targetMajor) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('savings_goals', {
      'id': AppDatabase.newId(),
      'name': name,
      'owner_id': ownerId,
      'target_amount_minor': (targetMajor * 100).round(),
      'current_amount_minor': 0,
      'currency': Defaults.currency,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> contributeSavings(String goalId, double amountMajor, {String? accountId}) async {
    final now = AppDatabase.nowMs();
    final minor = (amountMajor * 100).round();
    final db = await _db.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) return;
    final current = ((rows.first['current_amount_minor'] as int?) ?? 0) + minor;
    final target = (rows.first['target_amount_minor'] as int?) ?? 0;
    final reached = target > 0 && current >= target;
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await txn.update(
        'savings_goals',
        {
          'current_amount_minor': current,
          if (reached) 'status': 'REACHED',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await txn.insert('savings_contributions', {
        'id': AppDatabase.newId(),
        'goal_id': goalId,
        'amount_minor': minor,
        'occurred_at': now,
        'account_id': accountId,
        'created_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': reached ? 'SAVINGS_GOAL_REACHED' : 'SAVINGS_CONTRIBUTION_RECORDED',
        'entity_type': 'SAVINGS_GOAL',
        'entity_id': goalId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<List<Map<String, Object?>>> search(String q) async {
    final like = '%${q.trim()}%';
    final db = await _db.database;
    final out = <Map<String, Object?>>[];
    try {
      final tasks = await db.query('tasks', where: 'title LIKE ?', whereArgs: [like], limit: 20);
      for (final t in tasks) {
        out.add({'kind': 'TASK', ...t});
      }
    } catch (_) {}
    try {
      final notes = await db.query('notes', where: 'content LIKE ?', whereArgs: [like], limit: 10);
      for (final n in notes) {
        out.add({'kind': 'NOTE', ...n});
      }
    } catch (_) {}
    return out;
  }

  // ---- Practical life: documents, maintenance, shopping, appointments ----

  Future<List<Map<String, Object?>>> listDocuments() async {
    final db = await _db.database;
    try {
      return await db.query(
        'documents',
        where: "status IS NULL OR status != 'ARCHIVED'",
        orderBy: 'expires_at ASC, updated_at DESC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> addDocument(String title, {DateTime? expiresAt}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('documents', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listPractical() async {
    final db = await _db.database;
    try {
      return await db.query(
        'practical_items',
        where: "status IS NULL OR status NOT IN ('DONE', 'CANCELLED')",
        orderBy: 'due_at ASC, updated_at DESC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> addPractical(String title, {String? type, DateTime? dueAt}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final row = <String, Object?>{
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': type != null && type.isNotEmpty ? '[$type] $title' : title,
      'status': 'OPEN',
      'due_at': dueAt?.millisecondsSinceEpoch,
      'created_at': now,
      'updated_at': now,
    };
    await (await _db.database).insert('practical_items', row);
  }

  Future<List<Map<String, Object?>>> listUpcomingAppointments({int days = 14}) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final until = now + Duration(days: days).inMilliseconds;
    try {
      return await db.query(
        'calendar_events',
        where: "start_at >= ? AND start_at <= ? AND (status IS NULL OR status != 'CANCELLED')",
        whereArgs: [now - const Duration(hours: 1).inMilliseconds, until],
        orderBy: 'start_at ASC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, Object?>>> listShoppingLists() async {
    final db = await _db.database;
    try {
      return await db.query('shopping_lists', orderBy: 'updated_at DESC');
    } catch (_) {
      return [];
    }
  }

  Future<void> addShoppingList(String name) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('shopping_lists', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
  }
}
