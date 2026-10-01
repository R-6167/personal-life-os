import Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';
import {
  RecurrenceGenerator,
  type RecurrenceEntityType,
} from '../recurrence/recurrence-generator.js';
import {
  type OccurrenceGenerationOptions,
  type RecurrenceRule,
} from '../recurrence/recurrence-types.js';

export type OccurrenceStatus =
  | 'EXPECTED'
  | 'COMPLETED'
  | 'MISSED'
  | 'SKIPPED'
  | 'PARTIAL'
  | 'UPCOMING'
  | 'DUE'
  | 'OVERDUE'
  | 'PAID';

export interface HabitOccurrenceRecord {
  id: string;
  habitId: string;
  scheduledDate: number;
  scheduledTime?: number | null;
  status: OccurrenceStatus;
  completedAt?: number | null;
  skippedAt?: number | null;
  actualDurationMinutes?: number | null;
  reason?: string | null;
  notes?: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface RoutineOccurrenceRecord {
  id: string;
  routineId: string;
  scheduledDate: number;
  scheduledTime?: number | null;
  status: OccurrenceStatus;
  startedAt?: number | null;
  completedAt?: number | null;
  createdAt: number;
  updatedAt: number;
}

export interface BillOccurrenceRecord {
  id: string;
  billId: string;
  periodStart?: number | null;
  periodEnd?: number | null;
  dueAt: number;
  expectedAmount?: number | null;
  actualAmount?: number | null;
  status: OccurrenceStatus;
  paidAt?: number | null;
  expenseId?: string | null;
  createdAt: number;
  updatedAt: number;
}

export class OccurrenceService {
  constructor(private readonly db: Database.Database) {}

  createHabitOccurrence(
    habitId: string,
    scheduledDate: number,
    scheduledTime?: number | null,
    status: OccurrenceStatus = 'EXPECTED',
    overrides: Partial<Omit<HabitOccurrenceRecord, 'id' | 'habitId' | 'scheduledDate' | 'scheduledTime' | 'createdAt' | 'updatedAt'>> = {}
  ): HabitOccurrenceRecord {
    const now = Date.now();
    const record: HabitOccurrenceRecord = {
      id: randomUUID(),
      habitId,
      scheduledDate,
      scheduledTime: scheduledTime ?? null,
      status,
      completedAt: overrides.completedAt ?? null,
      skippedAt: overrides.skippedAt ?? null,
      actualDurationMinutes: overrides.actualDurationMinutes ?? null,
      reason: overrides.reason ?? null,
      notes: overrides.notes ?? null,
      createdAt: now,
      updatedAt: now,
    };

    this.db.prepare(`
      INSERT INTO habit_occurrences (
        id, habit_id, scheduled_date, scheduled_time, status,
        completed_at, skipped_at, actual_duration_minutes,
        reason, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      record.id,
      record.habitId,
      record.scheduledDate,
      record.scheduledTime,
      record.status,
      record.completedAt,
      record.skippedAt,
      record.actualDurationMinutes,
      record.reason,
      record.notes,
      record.createdAt,
      record.updatedAt
    );

    return record;
  }

  createRoutineOccurrence(
    routineId: string,
    scheduledDate: number,
    scheduledTime?: number | null,
    status: OccurrenceStatus = 'EXPECTED',
    overrides: Partial<Omit<RoutineOccurrenceRecord, 'id' | 'routineId' | 'scheduledDate' | 'scheduledTime' | 'createdAt' | 'updatedAt'>> = {}
  ): RoutineOccurrenceRecord {
    const now = Date.now();
    const record: RoutineOccurrenceRecord = {
      id: randomUUID(),
      routineId,
      scheduledDate,
      scheduledTime: scheduledTime ?? null,
      status,
      startedAt: overrides.startedAt ?? null,
      completedAt: overrides.completedAt ?? null,
      createdAt: now,
      updatedAt: now,
    };

    this.db.prepare(`
      INSERT INTO routine_occurrences (
        id, routine_id, scheduled_date, scheduled_time, status,
        started_at, completed_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      record.id,
      record.routineId,
      record.scheduledDate,
      record.scheduledTime,
      record.status,
      record.startedAt,
      record.completedAt,
      record.createdAt,
      record.updatedAt
    );

    return record;
  }

  createBillOccurrence(
    billId: string,
    dueAt: number,
    status: OccurrenceStatus = 'UPCOMING',
    overrides: Partial<Omit<BillOccurrenceRecord, 'id' | 'billId' | 'dueAt' | 'createdAt' | 'updatedAt'>> = {}
  ): BillOccurrenceRecord {
    const now = Date.now();
    const record: BillOccurrenceRecord = {
      id: randomUUID(),
      billId,
      periodStart: overrides.periodStart ?? null,
      periodEnd: overrides.periodEnd ?? null,
      dueAt,
      expectedAmount: overrides.expectedAmount ?? null,
      actualAmount: overrides.actualAmount ?? null,
      status,
      paidAt: overrides.paidAt ?? null,
      expenseId: overrides.expenseId ?? null,
      createdAt: now,
      updatedAt: now,
    };

    this.db.prepare(`
      INSERT INTO bill_occurrences (
        id, bill_id, period_start, period_end, due_at, expected_amount,
        actual_amount, status, paid_at, expense_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      record.id,
      record.billId,
      record.periodStart,
      record.periodEnd,
      record.dueAt,
      record.expectedAmount,
      record.actualAmount,
      record.status,
      record.paidAt,
      record.expenseId,
      record.createdAt,
      record.updatedAt
    );

    return record;
  }

  generateHabitOccurrencesForRule(
    habitId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): HabitOccurrenceRecord[] {
    return this.persistGeneratedOccurrences(habitId, 'HABIT', rule, options);
  }

  generateBillOccurrencesForRule(
    billId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): BillOccurrenceRecord[] {
    const generated = RecurrenceGenerator.generateOccurrences(billId, 'BILL', rule, options);
    return generated.occurrences.map((occurrence) =>
      this.createBillOccurrence(billId, occurrence.scheduledDate, 'UPCOMING', {
        periodStart: options.fromDate,
        periodEnd: options.toDate,
        expectedAmount: null,
      })
    );
  }

  generateRoutineOccurrencesForRule(
    routineId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): RoutineOccurrenceRecord[] {
    return this.persistGeneratedOccurrences(routineId, 'ROUTINE', rule, options);
  }

  private persistGeneratedOccurrences<T extends { id: string }>(
    entityId: string,
    entityType: RecurrenceEntityType,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): T[] {
    const generated = RecurrenceGenerator.generateOccurrences(entityId, entityType, rule, options);

    const results: T[] = [];

    for (const occurrence of generated.occurrences) {
      if (entityType === 'HABIT') {
        const record = this.createHabitOccurrence(entityId, occurrence.scheduledDate, undefined, 'EXPECTED');
        results.push(record as T);
      } else if (entityType === 'ROUTINE') {
        const record = this.createRoutineOccurrence(entityId, occurrence.scheduledDate, undefined, 'EXPECTED');
        results.push(record as T);
      }
    }

    return results;
  }

  getHabitOccurrencesForDate(habitId: string, scheduledDate: number): HabitOccurrenceRecord[] {
    return this.db.prepare(`
      SELECT * FROM habit_occurrences
      WHERE habit_id = ? AND scheduled_date = ?
      ORDER BY scheduled_time ASC
    `).all(habitId, scheduledDate) as HabitOccurrenceRecord[];
  }

  getRoutineOccurrencesForDate(routineId: string, scheduledDate: number): RoutineOccurrenceRecord[] {
    return this.db.prepare(`
      SELECT * FROM routine_occurrences
      WHERE routine_id = ? AND scheduled_date = ?
      ORDER BY scheduled_time ASC
    `).all(routineId, scheduledDate) as RoutineOccurrenceRecord[];
  }
}

export function createOccurrenceService(db: Database.Database): OccurrenceService {
  return new OccurrenceService(db);
}
