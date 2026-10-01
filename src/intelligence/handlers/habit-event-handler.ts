import { EventRecorder } from './event-recorder.js';
import {
  HabitEventType,
  EntityType,
  EventSource,
  HabitCompletedMetadata,
} from '../types/events.js';

/**
 * HabitEventHandler manages events for habit-related operations.
 */
export class HabitEventHandler {
  constructor(private recorder: EventRecorder) {}

  /**
   * Record a habit created event.
   */
  recordHabitCreated(ownerId: string, habitId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: HabitEventType.HABIT_CREATED,
      entityType: EntityType.HABIT,
      entityId: habitId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a habit occurrence completed.
   * This is the most common event - when a user completes a scheduled habit.
   */
  recordHabitCompleted(
    ownerId: string,
    habitOccurrenceId: string,
    habitId: string,
    scheduledDate: number,
    actualDurationMinutes?: number,
    notes?: string
  ) {
    const metadata: HabitCompletedMetadata = {
      scheduledDate,
      actualDurationMinutes,
      notes,
    };

    // Record event on the occurrence, not the habit itself
    return this.recorder.recordEvent({
      ownerId,
      eventType: HabitEventType.HABIT_COMPLETED,
      entityType: EntityType.HABIT_OCCURRENCE,
      entityId: habitOccurrenceId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a habit occurrence skipped.
   * Skipped = user deliberately skipped it (not a miss, more intentional).
   */
  recordHabitSkipped(
    ownerId: string,
    habitOccurrenceId: string,
    habitId: string,
    scheduledDate: number,
    reason?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: HabitEventType.HABIT_SKIPPED,
      entityType: EntityType.HABIT_OCCURRENCE,
      entityId: habitOccurrenceId,
      source: EventSource.USER,
      metadata: {
        scheduledDate,
        reason,
      },
    });
  }

  /**
   * Record a habit occurrence missed.
   * Missed = it was due but not completed (system-generated event).
   */
  recordHabitMissed(
    ownerId: string,
    habitOccurrenceId: string,
    habitId: string,
    scheduledDate: number
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: HabitEventType.HABIT_MISSED,
      entityType: EntityType.HABIT_OCCURRENCE,
      entityId: habitOccurrenceId,
      source: EventSource.SYSTEM, // System detected this wasn't completed
      metadata: {
        scheduledDate,
      },
    });
  }

  /**
   * Record a habit occurrence marked as partial.
   */
  recordHabitPartial(
    ownerId: string,
    habitOccurrenceId: string,
    habitId: string,
    scheduledDate: number,
    actualDurationMinutes?: number,
    notes?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: HabitEventType.HABIT_PARTIAL,
      entityType: EntityType.HABIT_OCCURRENCE,
      entityId: habitOccurrenceId,
      source: EventSource.USER,
      metadata: {
        scheduledDate,
        actualDurationMinutes,
        notes,
      },
    });
  }
}
