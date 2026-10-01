import Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';
import { RecurrenceGenerator } from '../recurrence/recurrence-generator.js';
import type { OccurrenceGenerationOptions, RecurrenceRule } from '../recurrence/recurrence-types.js';

export type OccurrenceStatus = 'EXPECTED' | 'STARTED' | 'COMPLETED' | 'MISSED' | 'SKIPPED' | 'PARTIAL' | 'UPCOMING' | 'DUE' | 'OVERDUE' | 'PAID' | 'CANCELLED';

export interface HabitOccurrenceRecord { id: string; habitId: string; scheduledDate: number; scheduledTime: number | null; status: OccurrenceStatus; completedAt: number | null; skippedAt: number | null; actualDurationMinutes: number | null; reason: string | null; notes: string | null; createdAt: number; updatedAt: number; }
export interface RoutineOccurrenceRecord { id: string; routineId: string; scheduledDate: number; scheduledTime: number | null; status: OccurrenceStatus; startedAt: number | null; completedAt: number | null; createdAt: number; updatedAt: number; }
export interface BillOccurrenceRecord { id: string; billId: string; periodStart: number | null; periodEnd: number | null; dueAt: number; expectedAmountMinor: number | null; actualAmountMinor: number | null; status: OccurrenceStatus; paidAt: number | null; expenseId: string | null; createdAt: number; updatedAt: number; }

export class OccurrenceService {
  constructor(private readonly db: Database.Database) {}

  createHabitOccurrence(habitId: string, scheduledDate: number, scheduledTime: number | null = null): HabitOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db.prepare(`INSERT OR IGNORE INTO habit_occurrences (id, habit_id, scheduled_date, scheduled_time, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`).run(id, habitId, scheduledDate, scheduledTime, now, now);
    return this.db.prepare(`SELECT id, habit_id AS habitId, scheduled_date AS scheduledDate, scheduled_time AS scheduledTime, status, completed_at AS completedAt, skipped_at AS skippedAt, actual_duration_minutes AS actualDurationMinutes, reason, notes, created_at AS createdAt, updated_at AS updatedAt FROM habit_occurrences WHERE habit_id = ? AND scheduled_date = ? AND scheduled_time IS ?`).get(habitId, scheduledDate, scheduledTime) as HabitOccurrenceRecord;
  }

  createRoutineOccurrence(routineId: string, scheduledDate: number, scheduledTime: number | null = null): RoutineOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db.prepare(`INSERT OR IGNORE INTO routine_occurrences (id, routine_id, scheduled_date, scheduled_time, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?)`).run(id, routineId, scheduledDate, scheduledTime, now, now);
    return this.db.prepare(`SELECT id, routine_id AS routineId, scheduled_date AS scheduledDate, scheduled_time AS scheduledTime, status, started_at AS startedAt, completed_at AS completedAt, created_at AS createdAt, updated_at AS updatedAt FROM routine_occurrences WHERE routine_id = ? AND scheduled_date = ? AND scheduled_time IS ?`).get(routineId, scheduledDate, scheduledTime) as RoutineOccurrenceRecord;
  }

  createBillOccurrence(billId: string, dueAt: number, expectedAmountMinor: number | null = null): BillOccurrenceRecord {
    const now = Date.now();
    const id = randomUUID();
    this.db.prepare(`INSERT INTO bill_occurrences (id, bill_id, due_at, expected_amount_minor, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'UPCOMING', ?, ?)`).run(id, billId, dueAt, expectedAmountMinor, now, now);
    return this.db.prepare(`SELECT id, bill_id AS billId, period_start AS periodStart, period_end AS periodEnd, due_at AS dueAt, expected_amount_minor AS expectedAmountMinor, actual_amount_minor AS actualAmountMinor, status, paid_at AS paidAt, expense_id AS expenseId, created_at AS createdAt, updated_at AS updatedAt FROM bill_occurrences WHERE id = ?`).get(id) as BillOccurrenceRecord;
  }

  generateHabitOccurrencesForRule(habitId: string, rule: RecurrenceRule, options: OccurrenceGenerationOptions): HabitOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(habitId, 'HABIT', rule, options);
    return generated.occurrences.map((item) => this.createHabitOccurrence(habitId, item.scheduledDate));
  }

  generateRoutineOccurrencesForRule(routineId: string, rule: RecurrenceRule, options: OccurrenceGenerationOptions): RoutineOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(routineId, 'ROUTINE', rule, options);
    return generated.occurrences.map((item) => this.createRoutineOccurrence(routineId, item.scheduledDate));
  }

  generateBillOccurrencesForRule(billId: string, rule: RecurrenceRule, options: OccurrenceGenerationOptions, expectedAmountMinor: number | null = null): BillOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(billId, 'BILL', rule, options);
    return generated.occurrences.map((item) => this.createBillOccurrence(billId, item.scheduledDate, expectedAmountMinor));
  }
}

export function createOccurrenceService(db: Database.Database): OccurrenceService {
  return new OccurrenceService(db);
}
