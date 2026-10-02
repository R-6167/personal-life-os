import Database from 'better-sqlite3';
import { BaseRepository, mapRow, mapRows } from './base-repository.js';
import { nowMs, newId, type BillRecord, type BillOccurrenceRecord } from './repository-types.js';

export class BillRepository extends BaseRepository<BillRecord> {
  constructor(db: Database.Database) {
    super(db, 'bills');
  }

  create(
    input: Omit<BillRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & { id?: string }
  ): BillRecord {
    const now = nowMs();
    const item: BillRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      name: input.name,
      provider: input.provider ?? null,
      description: input.description ?? null,
      expectedAmountMinor: input.expectedAmountMinor ?? null,
      currency: input.currency,
      frequency: input.frequency ?? 'MONTHLY',
      nextDueAt: input.nextDueAt ?? now,
      status: input.status ?? 'ACTIVE',
      categoryId: input.categoryId ?? null,
      defaultAccountId: input.defaultAccountId ?? null,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db
      .prepare(
        `INSERT INTO bills (
          id, owner_id, name, provider, description, expected_amount_minor, currency,
          frequency, next_due_at, status, category_id, default_account_id,
          created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        item.id,
        item.ownerId,
        item.name,
        item.provider,
        item.description,
        item.expectedAmountMinor,
        item.currency,
        item.frequency,
        item.nextDueAt,
        item.status,
        item.categoryId,
        item.defaultAccountId,
        item.createdAt,
        item.updatedAt,
        item.archivedAt
      );

    return item;
  }

  update(id: string, changes: Partial<BillRecord>): BillRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: BillRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db
      .prepare(
        `UPDATE bills SET
          name = ?, provider = ?, description = ?, expected_amount_minor = ?, currency = ?,
          frequency = ?, next_due_at = ?, status = ?, category_id = ?, default_account_id = ?,
          updated_at = ?, archived_at = ?
        WHERE id = ?`
      )
      .run(
        next.name,
        next.provider,
        next.description,
        next.expectedAmountMinor,
        next.currency,
        next.frequency,
        next.nextDueAt,
        next.status,
        next.categoryId,
        next.defaultAccountId,
        next.updatedAt,
        next.archivedAt ?? null,
        id
      );

    return next;
  }

  findOccurrenceById(id: string): BillOccurrenceRecord | null {
    const row = this.db
      .prepare(`SELECT * FROM bill_occurrences WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;
    return mapRow<BillOccurrenceRecord>(row);
  }

  listOpenOccurrences(ownerId: string, beforeMs?: number): BillOccurrenceRecord[] {
    const params: unknown[] = [ownerId];
    let sql = `
      SELECT bo.*
      FROM bill_occurrences bo
      JOIN bills b ON b.id = bo.bill_id
      WHERE b.owner_id = ?
        AND bo.status IN ('UPCOMING', 'DUE', 'OVERDUE')
    `;
    if (beforeMs !== undefined) {
      sql += ` AND bo.due_at <= ?`;
      params.push(beforeMs);
    }
    sql += ` ORDER BY bo.due_at ASC`;
    const rows = this.db.prepare(sql).all(...params) as Record<string, unknown>[];
    return mapRows<BillOccurrenceRecord>(rows);
  }

  markOccurrencePaid(
    occurrenceId: string,
    actualAmountMinor: number,
    expenseId: string
  ): BillOccurrenceRecord | null {
    const now = nowMs();
    this.db
      .prepare(
        `UPDATE bill_occurrences
         SET status = 'PAID', paid_at = ?, actual_amount_minor = ?, expense_id = ?, updated_at = ?
         WHERE id = ?`
      )
      .run(now, actualAmountMinor, expenseId, now, occurrenceId);
    return this.findOccurrenceById(occurrenceId);
  }
}
