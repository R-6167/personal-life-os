import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/recurrence_engine.dart';
import 'database.dart';

class BillRepository {
  BillRepository(this._db);
  final AppDatabase _db;

  Future<List<Bill>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'bills',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [BillStatus.active],
      orderBy: 'next_due_at ASC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<List<BillOccurrence>> listOpenOccurrences() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT o.*, b.name AS bill_name, b.currency AS currency
      FROM bill_occurrences o
      JOIN bills b ON b.id = o.bill_id
      WHERE o.status IN (?, ?, ?)
      ORDER BY o.due_at ASC
    ''', [
      BillOccurrenceStatus.upcoming,
      BillOccurrenceStatus.due,
      BillOccurrenceStatus.overdue,
    ]);
    return rows.map(BillOccurrence.fromJoin).toList();
  }

  Future<void> refreshOccurrenceStatuses() async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    await db.rawUpdate(
      "UPDATE bill_occurrences SET status = ?, updated_at = ? WHERE status = ? AND due_at < ?",
      [BillOccurrenceStatus.overdue, now, BillOccurrenceStatus.upcoming, now],
    );
    await db.rawUpdate(
      "UPDATE bill_occurrences SET status = ?, updated_at = ? WHERE status = ? AND due_at <= ? AND due_at >= ?",
      [
        BillOccurrenceStatus.due,
        now,
        BillOccurrenceStatus.upcoming,
        AppDatabase.endOfTodayMs(),
        AppDatabase.startOfTodayMs(),
      ],
    );
  }

  Future<Bill> create({
    required String name,
    double? expectedMajor,
    int? dueInDays,
    String frequency = 'MONTHLY',
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final dueAt = now + Duration(days: dueInDays ?? 7).inMilliseconds;
    final minor = expectedMajor == null ? null : (expectedMajor * 100).round();
    final billId = AppDatabase.newId();
    final occId = AppDatabase.newId();

    await _db.txn((txn) async {
      await txn.insert('bills', {
        'id': billId,
        'owner_id': ownerId,
        'name': name,
        'expected_amount_minor': minor,
        'currency': Defaults.currency,
        'frequency': frequency,
        'next_due_at': dueAt,
        'status': BillStatus.active,
        'default_account_id': accountId,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('bill_occurrences', {
        'id': occId,
        'bill_id': billId,
        'due_at': dueAt,
        'expected_amount_minor': minor,
        'status': BillOccurrenceStatus.upcoming,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'BILL_CREATED',
        'entity_type': 'BILL',
        'entity_id': billId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
      await txn.insert('reminders', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'title': 'Bill due: $name',
        'message': 'Upcoming bill payment',
        'trigger_at': dueAt - const Duration(days: 1).inMilliseconds,
        'source_type': 'BILL',
        'source_id': billId,
        'status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      });
    });

    return Bill(
      id: billId,
      ownerId: ownerId,
      name: name,
      expectedAmountMinor: minor,
      currency: Defaults.currency,
      nextDueAt: dueAt,
      status: BillStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  int _nextDueMs(int fromMs, String frequency) {
    return RecurrenceEngine.nextAfter(fromMs, frequency: frequency);
  }

  /// Bill → expense → optional account debit → next occurrence → history events.
  Future<void> payOccurrence(
    BillOccurrence occ, {
    double? actualMajor,
    String? accountId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final amount = actualMajor != null
        ? (actualMajor * 100).round()
        : (occ.expectedAmountMinor ?? 0);
    final expenseId = AppDatabase.newId();
    final currency = occ.currency ?? Defaults.currency;

    final billRows = await (await _db.database).query(
      'bills',
      where: 'id = ?',
      whereArgs: [occ.billId],
      limit: 1,
    );
    final frequency = billRows.isEmpty ? 'MONTHLY' : (billRows.first['frequency'] as String? ?? 'MONTHLY');
    final defaultAccount = accountId ??
        (billRows.isEmpty ? null : billRows.first['default_account_id'] as String?);
    final nextDue = _nextDueMs(occ.dueAt, frequency);

    await _db.txn((txn) async {
      await txn.insert('expenses', {
        'id': expenseId,
        'owner_id': ownerId,
        'account_id': defaultAccount,
        'description': 'Bill: ${occ.billName ?? occ.billId}',
        'amount_minor': amount,
        'currency': currency,
        'occurred_at': now,
        'payment_method': 'BILL',
        'created_at': now,
        'updated_at': now,
      });

      if (defaultAccount != null) {
        final rows = await txn.query(
          'financial_accounts',
          where: 'id = ?',
          whereArgs: [defaultAccount],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final bal = ((rows.first['current_balance_minor'] as int?) ?? 0) - amount;
          await txn.update(
            'financial_accounts',
            {'current_balance_minor': bal, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [defaultAccount],
          );
        }
      }

      await txn.update(
        'bill_occurrences',
        {
          'status': BillOccurrenceStatus.paid,
          'paid_at': now,
          'actual_amount_minor': amount,
          'expense_id': expenseId,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [occ.id],
      );

      final nextOccId = AppDatabase.newId();
      await txn.insert('bill_occurrences', {
        'id': nextOccId,
        'bill_id': occ.billId,
        'due_at': nextDue,
        'expected_amount_minor': occ.expectedAmountMinor,
        'status': BillOccurrenceStatus.upcoming,
        'created_at': now,
        'updated_at': now,
      });

      await txn.update(
        'bills',
        {'next_due_at': nextDue, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [occ.billId],
      );

      await txn.insert('reminders', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'title': 'Bill due: ${occ.billName ?? 'Bill'}',
        'trigger_at': nextDue - const Duration(days: 1).inMilliseconds,
        'source_type': 'BILL',
        'source_id': occ.billId,
        'status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'BILL_PAID',
        'entity_type': 'BILL_OCCURRENCE',
        'entity_id': occ.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata':
            '{"amount":$amount,"currency":"$currency","expenseId":"$expenseId","accountId":"${defaultAccount ?? ''}","nextDue":$nextDue}',
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'EXPENSE_RECORDED',
        'entity_type': 'EXPENSE',
        'entity_id': expenseId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
