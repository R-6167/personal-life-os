import type { Db } from './database';
import { DEFAULT_OWNER_ID, uid } from './database';

async function recordEvent(
  db: Db,
  eventType: string,
  entityType: string,
  entityId: string,
  title?: string
): Promise<void> {
  const now = Date.now();
  await db.runAsync(
    `INSERT INTO activity_events (id, owner_id, event_type, entity_type, entity_id, occurred_at, recorded_at, source, metadata)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'APP', ?)`,
    uid('act'),
    DEFAULT_OWNER_ID,
    eventType,
    entityType,
    entityId,
    now,
    now,
    title ? JSON.stringify({ title }) : null
  );
}

export async function loadRoutines(db: Db) {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM routines WHERE owner_id = ? AND archived_at IS NULL ORDER BY title`,
    DEFAULT_OWNER_ID
  );
  const out = [];
  for (const r of rows) {
    const steps = await db.getAllAsync<Record<string, unknown>>(
      `SELECT * FROM routine_steps WHERE routine_id = ? ORDER BY sort_order ASC`,
      String(r.id)
    );
    out.push({
      id: String(r.id),
      title: String(r.title),
      description: r.description != null ? String(r.description) : null,
      status: String(r.status),
      estimatedMinutes: r.estimated_minutes != null ? Number(r.estimated_minutes) : null,
      frequency: String(r.frequency ?? 'DAILY'),
      steps: steps.map((s) => ({
        id: String(s.id),
        title: String(s.title),
        sortOrder: Number(s.sort_order ?? 0),
        estimatedMinutes: s.estimated_minutes != null ? Number(s.estimated_minutes) : null,
      })),
    });
  }
  return out;
}

export async function loadRoutineOccurrences(db: Db) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT ro.*, r.title AS title
     FROM routine_occurrences ro
     JOIN routines r ON r.id = ro.routine_id
     WHERE ro.owner_id = ? AND ro.scheduled_date >= ?
     ORDER BY ro.scheduled_date ASC`,
    DEFAULT_OWNER_ID,
    d.getTime()
  );
  return rows.map((r) => ({
    id: String(r.id),
    routineId: String(r.routine_id),
    title: String(r.title),
    scheduledDate: Number(r.scheduled_date),
    status: String(r.status),
  }));
}

export async function createRoutine(
  db: Db,
  input: {
    title: string;
    description?: string;
    estimatedMinutes?: number;
    frequency?: string;
    steps?: string[];
  }
): Promise<string> {
  const now = Date.now();
  const id = uid('rtn');
  await db.runAsync(
    `INSERT INTO routines (id, owner_id, title, description, status, estimated_minutes, frequency, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.title.trim(),
    input.description?.trim() || null,
    input.estimatedMinutes ?? null,
    input.frequency ?? 'DAILY',
    now,
    now
  );
  const steps = input.steps?.filter((s) => s.trim()) ?? [];
  for (let i = 0; i < steps.length; i++) {
    await db.runAsync(
      `INSERT INTO routine_steps (id, routine_id, title, sort_order, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      uid('rs'),
      id,
      steps[i].trim(),
      i,
      now
    );
  }
  const day = new Date();
  day.setHours(0, 0, 0, 0);
  await db.runAsync(
    `INSERT INTO routine_occurrences (id, routine_id, owner_id, scheduled_date, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`,
    uid('ro'),
    id,
    DEFAULT_OWNER_ID,
    day.getTime(),
    now,
    now
  );
  await recordEvent(db, 'ROUTINE_CREATED', 'ROUTINE', id, input.title.trim());
  return id;
}

export async function completeRoutineOccurrence(db: Db, id: string): Promise<void> {
  const now = Date.now();
  const row = await db.getFirstAsync<{ title: string }>(
    `SELECT r.title AS title FROM routine_occurrences ro JOIN routines r ON r.id = ro.routine_id WHERE ro.id = ?`,
    id
  );
  await db.runAsync(
    `UPDATE routine_occurrences SET status = 'COMPLETED', completed_at = ?, updated_at = ? WHERE id = ?`,
    now,
    now,
    id
  );
  if (row) await recordEvent(db, 'ROUTINE_COMPLETED', 'ROUTINE', id, row.title);
}

export async function ensureRoutineOccurrences(db: Db): Promise<number> {
  const day = new Date();
  day.setHours(0, 0, 0, 0);
  const today = day.getTime();
  const routines = await db.getAllAsync<{ id: string }>(
    `SELECT id FROM routines WHERE owner_id = ? AND status = 'ACTIVE' AND archived_at IS NULL`,
    DEFAULT_OWNER_ID
  );
  let n = 0;
  for (const r of routines) {
    const exists = await db.getFirstAsync<{ id: string }>(
      `SELECT id FROM routine_occurrences WHERE routine_id = ? AND scheduled_date = ? LIMIT 1`,
      r.id,
      today
    );
    if (!exists) {
      const now = Date.now();
      await db.runAsync(
        `INSERT INTO routine_occurrences (id, routine_id, owner_id, scheduled_date, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`,
        uid('ro'),
        r.id,
        DEFAULT_OWNER_ID,
        today,
        now,
        now
      );
      n += 1;
    }
  }
  await db.runAsync(
    `UPDATE routine_occurrences SET status = 'MISSED', updated_at = ?
     WHERE owner_id = ? AND status = 'EXPECTED' AND scheduled_date < ?`,
    Date.now(),
    DEFAULT_OWNER_ID,
    today
  );
  return n;
}

export async function loadIncome(db: Db) {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM income WHERE owner_id = ? ORDER BY occurred_at DESC LIMIT 40`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    description: String(r.description),
    amountMinor: Number(r.amount_minor),
    currency: String(r.currency ?? 'KES'),
    source: r.source != null ? String(r.source) : null,
    occurredAt: Number(r.occurred_at),
  }));
}

export async function createIncome(
  db: Db,
  input: { description: string; amountMinor: number; source?: string; accountId?: string | null }
): Promise<string> {
  const now = Date.now();
  const id = uid('inc');
  await db.runAsync(
    `INSERT INTO income (id, owner_id, account_id, description, amount_minor, currency, source, occurred_at, created_at)
     VALUES (?, ?, ?, ?, ?, 'KES', ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.accountId ?? null,
    input.description.trim(),
    input.amountMinor,
    input.source?.trim() || null,
    now,
    now
  );
  if (input.accountId) {
    await db.runAsync(
      `UPDATE financial_accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ?`,
      input.amountMinor,
      now,
      input.accountId
    );
  } else {
    const acc = await db.getFirstAsync<{ id: string }>(
      `SELECT id FROM financial_accounts WHERE owner_id = ? LIMIT 1`,
      DEFAULT_OWNER_ID
    );
    if (acc) {
      await db.runAsync(
        `UPDATE financial_accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ?`,
        input.amountMinor,
        now,
        acc.id
      );
    }
  }
  await recordEvent(db, 'INCOME_RECORDED', 'INCOME', id, input.description.trim());
  return id;
}
