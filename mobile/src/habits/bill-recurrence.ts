import type { Db } from '../db/database';
import { DEFAULT_OWNER_ID, uid } from '../db/database';
import { startOfDay } from './recurrence';

type BillRow = {
  id: string;
  name: string;
  expected_amount_minor: number;
  frequency: string;
  interval: number;
  next_due_at: number | null;
  created_at: number;
};

function addFrequency(from: number, frequency: string, interval: number): number {
  const d = new Date(from);
  const freq = (frequency || 'MONTHLY').toUpperCase();
  const n = Math.max(1, interval || 1);
  if (freq === 'WEEKLY') {
    d.setDate(d.getDate() + 7 * n);
  } else if (freq === 'YEARLY') {
    d.setFullYear(d.getFullYear() + n);
  } else {
    d.setMonth(d.getMonth() + n);
  }
  return startOfDay(d.getTime());
}

export async function ensureBillOccurrences(
  db: Db,
  options?: { daysAhead?: number }
): Promise<{ generated: number; overdue: number }> {
  const today = startOfDay();
  const daysAhead = options?.daysAhead ?? 45;
  const horizon = today + daysAhead * 86400000;
  let generated = 0;
  let overdue = 0;

  const miss = await db.runAsync(
    `UPDATE bill_occurrences
     SET status = 'OVERDUE', updated_at = ?
     WHERE owner_id = ?
       AND status IN ('UPCOMING', 'DUE')
       AND due_at < ?`,
    Date.now(),
    DEFAULT_OWNER_ID,
    today
  );
  overdue = miss.changes ?? 0;

  await db.runAsync(
    `UPDATE bill_occurrences
     SET status = 'DUE', updated_at = ?
     WHERE owner_id = ?
       AND status = 'UPCOMING'
       AND due_at >= ? AND due_at < ?`,
    Date.now(),
    DEFAULT_OWNER_ID,
    today,
    today + 86400000
  );

  const bills = await db.getAllAsync<BillRow>(
    `SELECT id, name, expected_amount_minor,
            COALESCE(frequency, 'MONTHLY') AS frequency,
            COALESCE(interval, 1) AS interval,
            next_due_at, created_at
     FROM bills
     WHERE owner_id = ? AND status = 'ACTIVE'`,
    DEFAULT_OWNER_ID
  );

  for (const bill of bills) {
    let next = bill.next_due_at
      ? startOfDay(bill.next_due_at)
      : startOfDay(bill.created_at);

    let guard = 0;
    while (next < today && guard < 120) {
      next = addFrequency(next, bill.frequency, bill.interval);
      guard += 1;
    }

    while (next <= horizon && guard < 200) {
      const existing = await db.getFirstAsync<{ id: string }>(
        `SELECT id FROM bill_occurrences WHERE bill_id = ? AND due_at = ? LIMIT 1`,
        bill.id,
        next
      );
      if (!existing) {
        const now = Date.now();
        const status = next < today ? 'OVERDUE' : next < today + 86400000 ? 'DUE' : 'UPCOMING';
        await db.runAsync(
          `INSERT INTO bill_occurrences
             (id, bill_id, owner_id, due_at, expected_amount_minor, status, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          uid('bo'),
          bill.id,
          DEFAULT_OWNER_ID,
          next,
          bill.expected_amount_minor,
          status,
          now,
          now
        );
        generated += 1;
      }
      next = addFrequency(next, bill.frequency, bill.interval);
      guard += 1;
    }

    const soon = await db.getFirstAsync<{ due_at: number }>(
      `SELECT due_at FROM bill_occurrences
       WHERE bill_id = ? AND status IN ('UPCOMING','DUE','OVERDUE')
       ORDER BY due_at ASC LIMIT 1`,
      bill.id
    );
    if (soon) {
      await db.runAsync(
        `UPDATE bills SET next_due_at = ?, updated_at = ? WHERE id = ?`,
        soon.due_at,
        Date.now(),
        bill.id
      );
    }
  }

  return { generated, overdue };
}
