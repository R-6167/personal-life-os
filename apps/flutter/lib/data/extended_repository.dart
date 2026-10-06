import '../domain/enums.dart';
import '../services/domain_recurrence.dart';
import 'database.dart';

/// People, calendar, debt, savings, practical, shopping, search.
class ExtendedRepository {
  ExtendedRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listPeople() async {
    return (await _db.database).query('people', orderBy: 'name ASC');
  }

  Future<void> addPerson(String name, {String? phone, String? email}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('people', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'name': name,
      'phone': phone,
      'email': email,
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

  Future<void> completeReminder(String id) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'reminders',
      {'status': 'DONE', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelReminder(String id) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'reminders',
      {'status': 'CANCELLED', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> listEvents() async {
    return (await _db.database).query(
      'calendar_events',
      where: "status IS NULL OR status != 'CANCELLED'",
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
}
