import { EventRecorder } from './event-recorder.js';
import {
  TaskEventType,
  EntityType,
  EventSource,
  TaskCompletedMetadata,
} from '../types/events.js';

/**
 * TaskEventHandler manages events for task-related operations.
 * These handlers are called by task domain services after updating the database.
 */
export class TaskEventHandler {
  constructor(private recorder: EventRecorder) {}

  /**
   * Record a task creation event.
   */
  recordTaskCreated(ownerId: string, taskId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_CREATED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task update event.
   */
  recordTaskUpdated(ownerId: string, taskId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_UPDATED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task started event.
   */
  recordTaskStarted(ownerId: string, taskId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_STARTED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task paused event.
   */
  recordTaskPaused(ownerId: string, taskId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_PAUSED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task completed event.
   * Includes metadata about status change and time spent.
   */
  recordTaskCompleted(
    ownerId: string,
    taskId: string,
    previousStatus: string,
    actualMinutes?: number,
    estimatedMinutes?: number
  ) {
    const metadata: TaskCompletedMetadata = {
      previousStatus,
      newStatus: 'COMPLETED',
      actualMinutes,
      estimatedMinutes,
    };

    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_COMPLETED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task reopened event.
   */
  recordTaskReopened(ownerId: string, taskId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_REOPENED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a task cancelled event.
   */
  recordTaskCancelled(ownerId: string, taskId: string, reason?: string) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_CANCELLED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata: reason ? { reason } : undefined,
    });
  }

  /**
   * Record a task deferred event.
   */
  recordTaskDeferred(ownerId: string, taskId: string, newDueDate?: number) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: TaskEventType.TASK_DEFERRED,
      entityType: EntityType.TASK,
      entityId: taskId,
      source: EventSource.USER,
      metadata: newDueDate ? { newDueDate } : undefined,
    });
  }
}
