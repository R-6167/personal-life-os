import Database from 'better-sqlite3';
import { EventRecorder } from './event-recorder.js';
import { TaskEventHandler } from './handlers/task-event-handler.js';
import { HabitEventHandler } from './handlers/habit-event-handler.js';
import { ProjectEventHandler } from './handlers/project-event-handler.js';
import { FinanceEventHandler } from './handlers/finance-event-handler.js';
import { RoutineEventHandler } from './handlers/routine-event-handler.js';
import { EventLogEntry, CreateEventParams } from '../types/events.js';

/**
 * EventBus is the central orchestrator for the event recording system.
 * 
 * It provides a single entry point that coordinates:
 * - Raw event recording (for direct event logging)
 * - Domain-specific event handlers (tasks, habits, projects, etc.)
 * - Transactional writes (event + entity changes together)
 * - Event queries (accessing the activity log)
 * 
 * Usage pattern:
 * ```
 * const bus = new EventBus(db);
 * 
 * // Via domain handlers
 * bus.task.recordTaskCompleted(ownerId, taskId, previousStatus);
 * bus.habit.recordHabitCompleted(ownerId, habitOccId, habitId, scheduledDate);
 * 
 * // Or direct recording
 * bus.recordEvent({ ownerId, eventType, entityType, entityId });
 * 
 * // Transactional context
 * bus.transaction((recorder) => {
 *   // Update entity
 *   updateTaskInDB(db, taskId, { status: 'COMPLETED' });
 *   // Record event atomically
 *   bus.task.recordTaskCompleted(ownerId, taskId, previousStatus);
 * });
 * ```
 */
export class EventBus {
  private recorder: EventRecorder;

  // Domain-specific handlers
  task: TaskEventHandler;
  habit: HabitEventHandler;
  project: ProjectEventHandler;
  finance: FinanceEventHandler;
  routine: RoutineEventHandler;

  constructor(db: Database.Database) {
    this.recorder = new EventRecorder(db);
    this.task = new TaskEventHandler(this.recorder);
    this.habit = new HabitEventHandler(this.recorder);
    this.project = new ProjectEventHandler(this.recorder);
    this.finance = new FinanceEventHandler(this.recorder);
    this.routine = new RoutineEventHandler(this.recorder);
  }

  /**
   * Record a single event directly.
   * Use domain handlers (task, habit, etc.) when possible for consistency.
   */
  recordEvent(params: CreateEventParams): EventLogEntry {
    return this.recorder.recordEvent(params);
  }

  /**
   * Record multiple events atomically.
   * All events are recorded together in a single batch.
   */
  recordEvents(eventParams: CreateEventParams[]): EventLogEntry[] {
    return this.recorder.recordEvents(eventParams);
  }

  /**
   * Execute a function within a database transaction.
   * Use this when entity updates and event recording must happen together.
   * 
   * Example:
   * ```
   * bus.transaction((bus) => {
   *   db.prepare('UPDATE tasks SET status = ? WHERE id = ?')
   *     .run('COMPLETED', taskId);
   *   bus.task.recordTaskCompleted(ownerId, taskId, 'IN_PROGRESS');
   * });
   * ```
   * 
   * If an error occurs, both the entity update and event are rolled back.
   */
  transaction<T>(fn: (bus: EventBus) => T): T {
    return this.recorder.transaction(() => fn(this));
  }

  // ============ QUERY METHODS ============

  /**
   * Get events for a specific entity.
   */
  getEventsByEntity(ownerId: string, entityType: string, entityId: string): EventLogEntry[] {
    return this.recorder.getEventsByEntity(ownerId, entityType, entityId);
  }

  /**
   * Get events by type (e.g., all TASK_COMPLETED events).
   */
  getEventsByType(ownerId: string, eventType: string, limit?: number): EventLogEntry[] {
    return this.recorder.getEventsByType(ownerId, eventType, limit);
  }

  /**
   * Get events in a time range.
   */
  getEventsByTimeRange(
    ownerId: string,
    startTime: number,
    endTime: number,
    limit?: number
  ): EventLogEntry[] {
    return this.recorder.getEventsByTimeRange(ownerId, startTime, endTime, limit);
  }

  /**
   * Get the most recent events (useful for activity stream/dashboard).
   */
  getRecentEvents(ownerId: string, limit?: number): EventLogEntry[] {
    return this.recorder.getRecentEvents(ownerId, limit);
  }

  /**
   * Check if an external event has already been imported (idempotency).
   */
  hasExternalEvent(source: string, externalId: string): boolean {
    return this.recorder.hasExternalEvent(source, externalId);
  }

  /**
   * Get a specific event by ID.
   */
  getEventById(id: string): EventLogEntry | null {
    return this.recorder.getEventById(id);
  }

  /**
   * Count events by type (useful for insights/statistics).
   */
  countEventsByType(ownerId: string, eventType: string): number {
    return this.recorder.countEventsByType(ownerId, eventType);
  }

  /**
   * Count all events for an owner.
   */
  countAllEvents(ownerId: string): number {
    return this.recorder.countAllEvents(ownerId);
  }

  /**
   * Get the recorder directly for advanced use cases.
   * Prefer using domain handlers or the EventBus methods.
   */
  getRecorder(): EventRecorder {
    return this.recorder;
  }
}

/**
 * Factory function to create an EventBus instance.
 */
export function createEventBus(db: Database.Database): EventBus {
  return new EventBus(db);
}
