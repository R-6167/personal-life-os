import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';

export type RecurrenceFrequency = 'DAILY' | 'WEEKLY' | 'MONTHLY';
export interface RecurrenceRule { frequency: RecurrenceFrequency; intervalValue?: number; daysOfWeek?: number[]; dayOfMonth?: number; startDate: number; endDate?: number | null; timezone: string; }
export interface GeneratedOccurrence { id: string; scheduledDate: number; scheduledTime?: number | null; }

const DAY = 86_400_000;
const utcDate = (timestamp: number) => { const date = new Date(timestamp); return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())); };

export class OccurrenceGenerator {
  generate(rule: RecurrenceRule, from: number, to: number): GeneratedOccurrence[] {
    const interval = Math.max(1, rule.intervalValue ?? 1);
    const start = utcDate(Math.max(from, rule.startDate));
    const end = utcDate(rule.endDate ? Math.min(to, rule.endDate) : to);
    const occurrences: GeneratedOccurrence[] = [];
    for (let cursor = start.getTime(); cursor <= end.getTime(); cursor += DAY) {
      const date = new Date(cursor);
      const daysSinceStart = Math.floor((cursor - utcDate(rule.startDate).getTime()) / DAY);
      const dayMatches = rule.frequency === 'DAILY'
        ? daysSinceStart >= 0 && daysSinceStart % interval === 0
        : rule.frequency === 'WEEKLY'
          ? Math.floor(daysSinceStart / 7) % interval === 0 && (rule.daysOfWeek?.includes(date.getUTCDay()) ?? date.getUTCDay() === utcDate(rule.startDate).getUTCDay())
          : date.getUTCDate() === (rule.dayOfMonth ?? utcDate(rule.startDate).getUTCDate()) && Math.floor((date.getUTCFullYear() - utcDate(rule.startDate).getUTCFullYear()) * 12 + date.getUTCMonth() - utcDate(rule.startDate).getUTCMonth()) % interval === 0;
      if (dayMatches) occurrences.push({ id: randomUUID(), scheduledDate: cursor });
    }
    return occurrences;
  }
}

export class RecurrenceRepository {
  constructor(private readonly db: Database.Database) {}

  saveTaskOccurrence(taskId: string, occurrence: GeneratedOccurrence): void {
    this.db.prepare(`INSERT OR IGNORE INTO task_occurrences (id, task_id, scheduled_date, status, created_at, updated_at) VALUES (?, ?, ?, 'EXPECTED', ?, ?)`)
      .run(occurrence.id, taskId, occurrence.scheduledDate, Date.now(), Date.now());
  }

  saveHabitOccurrence(habitId: string, occurrence: GeneratedOccurrence): void {
    this.db.prepare(`INSERT OR IGNORE INTO habit_occurrences (id, habit_id, scheduled_date, scheduled_time, status, created_at, updated_at) VALUES (?, ?, ?, NULL, 'EXPECTED', ?, ?)`)
      .run(occurrence.id, habitId, occurrence.scheduledDate, Date.now(), Date.now());
  }
}
