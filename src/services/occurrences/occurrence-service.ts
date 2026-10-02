import Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';
import { RecurrenceGenerator } from '../recurrence/recurrence-generator.js';
import type { OccurrenceGenerationOptions, RecurrenceRule } from '../recurrence/recurrence-types.js';
import { mapRow } from '../repositories/base-repository.js';

export type OccurrenceStatus =
  | 'EXPECTED'
  | 'STARTED'
  | 'COMPLETED'
  | 'MISSED'
  | 'SKIPPED'
  | 'PARTIAL'
  | 'UPCOMING'
  | 'DUE'
  | 'OVERDUE'
  | 'PAID'
  | 'CANCELLED';

export interface HabitOccurrenceRecord {
  id: string;
  habitId: string;
  scheduledDate: number;
  scheduledTime: number | null;
  status: OccurrenceStatus;
  completedAt: number | null;
  skippedAt: number | null;
  actualDurationMinutes: number | null;
  reason: string | null;
  notes: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface RoutineOccurrenceRecord {
  id: string;
  routineId: string;
  scheduledDate: number;
  scheduledTime: number | null;
  status: OccurrenceStatus;
  startedAt: number | null;
  completedAt: number | null;
  createdAt: number;
  updatedAt: number;
}

export interface BillOccurrenceRecord {
  id: string;
  billId: string;
  periodStart: number | null;
  periodEnd: number | null;
  dueAt: number;
  expectedAmountMinor: number | null;
  actualAmountMinor: number | null;
  status: OccurrenceStatus;
  paidAt: number | null;
  expenseId: string | null;
  createdAt: number;
  updatedAt: number;
}

export class OccurrenceService {
  constructor(private readonly db: Database.Database) {}

  // ── Habit occurrences ─────────────────────────────────────────────────────

  createHabitOccurrence(
    habitId: string,
    scheduledDate: number,
    scheduledTime: number | null = null
  ): HabitOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db
      .prepare(
        `INSERT OR IGNORE INTO habit_occurrences
         (id, habit_id, scheduled_date, scheduled_time, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`
      )
      .run(id, habitId, scheduledDate, scheduledTime, now, now);

    return this.getHabitOccurrenceByHabitAndDate(habitId, scheduledDate, scheduledTime)!;
  }

  getHabitOccurrenceById(id: string): HabitOccurrenceRecord | null {
    const row = this.db
      .prepare(`SELECT * FROM habit_occurrences WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;
    return mapRow<HabitOccurrenceRecord>(row);
  }

  getHabitOccurrenceByHabitAndDate(
    habitId: string,
    scheduledDate: number,
    scheduledTime: number | null
  ): HabitOccurrenceRecord | null {
    const row = this.db
      .prepare(
        `SELECT * FROM habit_occurrences
         WHERE habit_id = ? AND scheduled_date = ? AND scheduled_time IS ?`
      )
      .get(habitId, scheduledDate, scheduledTime) as Record<string, unknown> | undefined;
    return mapRow<HabitOccurrenceRecord>(row);
  }

  completeHabitOccurrence(
    occurrenceId: string,
    opts?: { actualDurationMinutes?: number; notes?: string }
  ): HabitOccurrenceRecord {
    const now = Date.now();
    this.db
      .prepare(
        `UPDATE habit_occurrences
         SET status = 'COMPLETED',
             completed_at = ?,
             actual_duration_minutes = COALESCE(?, actual_duration_minutes),
             notes = COALESCE(?, notes),
             updated_at = ?
         WHERE id = ?`
      )
      .run(now, opts?.actualDurationMinutes ?? null, opts?.notes ?? null, now, occurrenceId);

    const updated = this.getHabitOccurrenceById(occurrenceId);
    if (!updated) throw new Error(`Habit occurrence not found after complete: ${occurrenceId}`);
    return updated;
  }

  skipHabitOccurrence(occurrenceId: string, reason?: string): HabitOccurrenceRecord {
    const now = Date.now();
    this.db
      .prepare(
        `UPDATE habit_occurrences
         SET status = 'SKIPPED',
             skipped_at = ?,
             reason = COALESCE(?, reason),
             updated_at = ?
         WHERE id = ?`
      )
      .run(now, reason ?? null, now, occurrenceId);

    const updated = this.getHabitOccurrenceById(occurrenceId);
    if (!updated) throw new Error(`Habit occurrence not found after skip: ${occurrenceId}`);
    return updated;
  }

  generateHabitOccurrencesForRule(
    habitId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): HabitOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(habitId, 'HABIT', rule, options);
    return generated.occurrences.map((item) =>
      this.createHabitOccurrence(habitId, item.scheduledDate)
    );
  }

  // ── Routine occurrences ───────────────────────────────────────────────────

  createRoutineOccurrence(
    routineId: string,
    scheduledDate: number,
    scheduledTime: number | null = null
  ): RoutineOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db
      .prepare(
        `INSERT OR IGNORE INTO routine_occurrences
         (id, routine_id, scheduled_date, scheduled_time, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`
      )
      .run(id, routineId, scheduledDate, scheduledTime, now, now);

    const row = this.db
      .prepare(
        `SELECT * FROM routine_occurrences
         WHERE routine_id = ? AND scheduled_date = ? AND scheduled_time IS ?`
      )
      .get(routineId, scheduledDate, scheduledTime) as Record<string, unknown> | undefined;
    return mapRow<RoutineOccurrenceRecord>(row)!;
  }

  generateRoutineOccurrencesForRule(
    routineId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): RoutineOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(routineId, 'ROUTINE', rule, options);
    return generated.occurrences.map((item) =>
      this.createRoutineOccurrence(routineId, item.scheduledDate)
    );
  }

  // ── Bill occurrences ──────────────────────────────────────────────────────

  createBillOccurrence(
    billId: string,
    dueAt: number,
    expectedAmountMinor: number | null = null
  ): BillOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db
      .prepare(
        `INSERT INTO bill_occurrences
         (id, bill_id, due_at, expected_amount_minor, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'UPCOMING', ?, ?)`
      )
      .run(id, billId, dueAt, expectedAmountMinor, now, now);

    const row = this.db
      .prepare(`SELECT * FROM bill_occurrences WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;
    return mapRow<BillOccurrenceRecord>(row)!;
  }

  generateBillOccurrencesForRule(
    billId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions,
    expectedAmountMinor: number | null = null
  ): BillOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(billId, 'BILL', rule, options);
    return generated.occurrences.map((item) =>
      this.createBillOccurrence(billId, item.scheduledDate, expectedAmountMinor)
    );
  }
}

export function createOccurrenceService(db: Database.Database): OccurrenceService {
  return new OccurrenceService(db);
}
