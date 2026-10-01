import type Database from 'better-sqlite3';
import { OccurrenceGenerator, RecurrenceRepository, type RecurrenceRule } from './recurrence-engine.js';

export class RecurrenceService {
  private readonly generator = new OccurrenceGenerator();
  private readonly repository: RecurrenceRepository;

  constructor(private readonly db: Database.Database) { this.repository = new RecurrenceRepository(db); }

  generateTaskOccurrences(taskId: string, rule: RecurrenceRule, from: number, to: number): number {
    const occurrences = this.generator.generate(rule, from, to);
    const transaction = this.db.transaction(() => occurrences.forEach((occurrence) => this.repository.saveTaskOccurrence(taskId, occurrence)));
    transaction();
    return occurrences.length;
  }

  generateHabitOccurrences(habitId: string, rule: RecurrenceRule, from: number, to: number): number {
    const occurrences = this.generator.generate(rule, from, to);
    const transaction = this.db.transaction(() => occurrences.forEach((occurrence) => this.repository.saveHabitOccurrence(habitId, occurrence)));
    transaction();
    return occurrences.length;
  }
}
