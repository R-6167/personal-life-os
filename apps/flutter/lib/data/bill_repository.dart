import '../domain/enums.dart';
import '../domain/models.dart';
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
    ''', [BillOccurrenceStatus.upcoming, BillOccurrenceStatus.due, BillOccurrenceStatus.overdue]);
    return rows.map(BillOccurrence.fromJoin).toList();
  }

  Future<Bill> create({equired String name, double? expectedMajor, int? dueInDays}) async {
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
        'frequency': 'MONTHLY',
        'next_due_at': dueAt,
        'status': BillStatus.active,
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

  /// Bill ≠ expense: paying creates expense + marks occurrence PAID + BILL_PAID event.
  Future<void> payOccurrence(BillOccurrence occ, {double? actualMajor}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final amount = actualMajor != null
        ? (actualMajor * 100).round()
        : (occ.expectedAmountMinor ?? 0);
    final expenseId = AppDatabase.newId();
    final currency = occ.currency ?? Defaults.currency;

    await _db.txn((txn) async {
      await txn.insert('expenses', {
        'id': expenseId,
        'owner_id': ownerId,
        'description': 'Bill: ${occ.billName ?? occ.billId}',
        'amount_minor': amount,
        'currency': currency,
        'occurred_at': now,
        'created_at': now,
        'updated_at': now,
      });
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
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'BILL_PAID',
        'entity_type': 'BILL_OCCURRENCE',
        'entity_id': occ.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"amount":$amount,"currency":"$currency","expenseId":"$expenseId"}',
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
