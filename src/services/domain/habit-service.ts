import Database from 'better-sqlite3';
import { EventBus } from '../../intelligence/event-bus.js';
import { HabitRepository } from '../repositories/habit-repository.js';
import { OccurrenceService } from '../occurrences/occurrence-service.js';
import type { HabitRecord } from '../repositories/repository-types.js';
import type { HabitOccurrenceRecord } from '../occurrences/occurrence-service.js';
import type { RecurrenceRule } from '../recurrence/recurrence-types.js';
import type { OccurrenceGenerationOptions } from '../recurrence/recurrence-types.js';
import { HabitEventType, EntityType, EventSource } from '../../types/events.js';
import { nowMs } from '../repositories/repository-types.js';

/**
 * HabitService — create habits, materialize occurrences, complete/skip with events.
 */
export class HabitService {
  private readonly habits: HabitRepository;
  private readonly occurrences: OccurrenceService;
  private readonly bus: EventBus;
  private readonly db: Database.Database;

  constructor(db: Database.Database, bus?: EventBus) {
    this.db = db;
    this.habits = new HabitRepository(db);
    this.occurrences = new OccurrenceService(db);
    this.bus = bus ?? new EventBus(db);
  }

  create(
    input: Omit<HabitRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & { id?: string }
  ): HabitRecord {
    return this.bus.transaction((bus) => {
      const habit = this.habits.create({
        ...input,
        status: input.status ?? 'ACTIVE',
        targetCount: input.targetCount ?? 1,
      });
      bus.habit.recordHabitCreated(habit.ownerId, habit.id, { title: habit.title });
      return habit;
    });
  }

  /**
   * Materialize expected occurrences for a date range from a recurrence rule.
   */
  generateOccurrences(
    habitId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): HabitOccurrenceRecord[] {
    return this.occurrences.generateHabitOccurrencesForRule(habitId, rule, options);
  }

  completeOccurrence(
    occurrenceId: string,
    opts?: { actualDurationMinutes?: number; notes?: string }
  ): HabitOccurrenceRecord {
    return this.bus.transaction((bus) => {
      const occ = this.occurrences.getHabitOccurrenceById(occurrenceId);
      if (!occ) throw new Error(`Habit occurrence not found: ${occurrenceId}`);

      const habit = this.habits.findById(occ.habitId);
      if (!habit) throw new Error(`Habit not found: ${occ.habitId}`);

      const completed = this.occurrences.completeHabitOccurrence(occurrenceId, {
        actualDurationMinutes: opts?.actualDurationMinutes,
        notes: opts?.notes,
      });

      bus.recordEvent({
        ownerId: habit.ownerId,
        eventType: HabitEventType.HABIT_COMPLETED,
        entityType: EntityType.HABIT_OCCURRENCE,
        entityId: occurrenceId,
        source: EventSource.USER,
        metadata: {
          habitId: occ.habitId,
          scheduledDate: occ.scheduledDate,
          actualDurationMinutes: opts?.actualDurationMinutes,
          notes: opts?.notes,
        },
      });

      return completed;
    });
  }

  skipOccurrence(occurrenceId: string, reason?: string): HabitOccurrenceRecord {
    return this.bus.transaction((bus) => {
      const occ = this.occurrences.getHabitOccurrenceById(occurrenceId);
      if (!occ) throw new Error(`Habit occurrence not found: ${occurrenceId}`);

      const habit = this.habits.findById(occ.habitId);
      if (!habit) throw new Error(`Habit not found: ${occ.habitId}`);

      const skipped = this.occurrences.skipHabitOccurrence(occurrenceId, reason);

      bus.recordEvent({
        ownerId: habit.ownerId,
        eventType: HabitEventType.HABIT_SKIPPED,
        entityType: EntityType.HABIT_OCCURRENCE,
        entityId: occurrenceId,
        source: EventSource.USER,
        metadata: {
          habitId: occ.habitId,
          scheduledDate: occ.scheduledDate,
          reason,
        },
      });

      return skipped;
    });
  }

  findById(id: string): HabitRecord | null {
    return this.habits.findById(id);
  }

  listByOwner(ownerId: string): HabitRecord[] {
    return this.habits.findByOwner(ownerId);
  }
}

export function createHabitService(db: Database.Database, bus?: EventBus): HabitService {
  return new HabitService(db, bus);
}
