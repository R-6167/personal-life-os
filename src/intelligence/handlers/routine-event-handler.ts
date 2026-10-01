import { EventRecorder } from './event-recorder.js';
import {
  RoutineEventType,
  EntityType,
  EventSource,
} from '../types/events.js';

/**
 * RoutineEventHandler manages events for routine-related operations.
 */
export class RoutineEventHandler {
  constructor(private recorder: EventRecorder) {}

  /**
   * Record a routine started event.
   */
  recordRoutineStarted(ownerId: string, routineOccurrenceId: string, routineId: string) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: RoutineEventType.ROUTINE_STARTED,
      entityType: EntityType.ROUTINE_OCCURRENCE,
      entityId: routineOccurrenceId,
      source: EventSource.USER,
      metadata: {
        routineId,
      },
    });
  }

  /**
   * Record a routine step completed event.
   */
  recordRoutineStepCompleted(
    ownerId: string,
    routineStepId: string,
    routineId: string,
    stepPosition: number,
    actualMinutes?: number
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: RoutineEventType.ROUTINE_STEP_COMPLETED,
      entityType: EntityType.ROUTINE_STEP,
      entityId: routineStepId,
      source: EventSource.USER,
      metadata: {
        routineId,
        stepPosition,
        actualMinutes,
      },
    });
  }

  /**
   * Record a routine step skipped event.
   */
  recordRoutineStepSkipped(
    ownerId: string,
    routineStepId: string,
    routineId: string,
    stepPosition: number,
    reason?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: RoutineEventType.ROUTINE_STEP_SKIPPED,
      entityType: EntityType.ROUTINE_STEP,
      entityId: routineStepId,
      source: EventSource.USER,
      metadata: {
        routineId,
        stepPosition,
        reason,
      },
    });
  }

  /**
   * Record a routine completed event.
   */
  recordRoutineCompleted(
    ownerId: string,
    routineOccurrenceId: string,
    routineId: string,
    totalActualMinutes?: number
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: RoutineEventType.ROUTINE_COMPLETED,
      entityType: EntityType.ROUTINE_OCCURRENCE,
      entityId: routineOccurrenceId,
      source: EventSource.USER,
      metadata: {
        routineId,
        totalActualMinutes,
      },
    });
  }

  /**
   * Record a routine missed event (system-generated).
   * When a scheduled routine was not completed.
   */
  recordRoutineMissed(ownerId: string, routineOccurrenceId: string, routineId: string) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: RoutineEventType.ROUTINE_MISSED,
      entityType: EntityType.ROUTINE_OCCURRENCE,
      entityId: routineOccurrenceId,
      source: EventSource.SYSTEM,
      metadata: {
        routineId,
      },
    });
  }
}
