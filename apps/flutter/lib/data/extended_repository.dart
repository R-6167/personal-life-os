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

  Future<String> addPerson(String name, {String? relationship, String? notes}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('people', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'relationship': relationship,
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listUpcomingAppointments({int days = 7}) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final end = now + Duration(days: days).inMilliseconds;
    return db.query(
      'calendar_events',
      where: 'start_at >= ? AND start_at <= ? AND archived_at IS NULL',
      whereArgs: [now, end],
      orderBy: 'start_at ASC',
    );
  }

  Future<String> addCalendarEvent({
    required String title,
    required int startAt,
    int? endAt,
    String? location,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('calendar_events', {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'start_at': startAt,
      'end_at': endAt,
      'location': location,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listDebts() async {
    final db = await _db.database;
    return db.query('debts', where: "status = 'OPEN'", orderBy: 'updated_at DESC');
  }

  Future<String> addDebt({
    required String counterparty,
    required String direction,
    required double amountMajor,
    String? notes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final minor = (amountMajor * 100).round();
    await (await _db.database).insert('debts', {
      'id': id,
      'owner_id': ownerId,
      'counterparty': counterparty,
      'direction': direction,
      'original_amount_minor': minor,
      'remaining_amount_minor': minor,
      'status': 'OPEN',
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listSavingsGoals() async {
    final db = await _db.database;
    return db.query('savings_goals', where: "status = 'ACTIVE'", orderBy: 'name ASC');
  }

  Future<String> addSavingsGoal({
    required String name,
    required double targetMajor,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('savings_goals', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'target_amount_minor': (targetMajor * 100).round(),
      'current_amount_minor': 0,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listPractical() async {
    final db = await _db.database;
    return db.query(
      'practical_items',
      where: "status != 'DONE' AND status != 'CANCELLED'",
      orderBy: 'due_at ASC NULLS LAST',
    );
  }

  Future<void> addPractical(
    String title, {
    String type = 'OTHER',
    DateTime? dueAt,
    String? notes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('practical_items', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'type': type,
      'due_at': dueAt?.millisecondsSinceEpoch,
      'status': 'OPEN',
      'notes': notes,
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
    final db = await _db.database;
    return db.query('documents', orderBy: 'expires_at ASC NULLS LAST');
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
      'type': type,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'document_number': documentNumber,
      'issuer': issuer,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listShoppingLists() async {
    final db = await _db.database;
    return db.query('shopping_lists', where: 'archived_at IS NULL', orderBy: 'name ASC');
  }

  Future<String> addShoppingList(String name) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('shopping_lists', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
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

  Future<List<Map<String, Object?>>> listPendingReminders() async {
    final db = await _db.database;
    return db.query(
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

  Future<String> addReminder({
    required String title,
    required int triggerAt,
    String? message,
    String? sourceType,
    String? sourceId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('reminders', {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'message': message,
      'trigger_at': triggerAt,
      'source_type': sourceType,
      'source_id': sourceId,
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }
}
