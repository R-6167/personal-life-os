import { EventRecorder } from './event-recorder.js';
import {
  ProjectEventType,
  GoalEventType,
  EntityType,
  EventSource,
  GoalProgressChangedMetadata,
} from '../types/events.js';

/**
 * ProjectEventHandler manages events for project and goal-related operations.
 */
export class ProjectEventHandler {
  constructor(private recorder: EventRecorder) {}

  // ============ PROJECT EVENTS ============

  /**
   * Record a project created event.
   */
  recordProjectCreated(ownerId: string, projectId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_CREATED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a project started event.
   */
  recordProjectStarted(ownerId: string, projectId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_STARTED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a project paused event.
   */
  recordProjectPaused(ownerId: string, projectId: string, reason?: string) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_PAUSED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata: reason ? { reason } : undefined,
    });
  }

  /**
   * Record a project resumed event.
   */
  recordProjectResumed(ownerId: string, projectId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_RESUMED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a project completed event.
   */
  recordProjectCompleted(ownerId: string, projectId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_COMPLETED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a project archived event.
   */
  recordProjectArchived(ownerId: string, projectId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.PROJECT_ARCHIVED,
      entityType: EntityType.PROJECT,
      entityId: projectId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a milestone completed event.
   */
  recordMilestoneCompleted(
    ownerId: string,
    milestoneId: string,
    projectId: string,
    metadata?: Record<string, unknown>
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: ProjectEventType.MILESTONE_COMPLETED,
      entityType: EntityType.MILESTONE,
      entityId: milestoneId,
      source: EventSource.USER,
      metadata: {
        projectId,
        ...metadata,
      },
    });
  }

  // ============ GOAL EVENTS ============

  /**
   * Record a goal created event.
   */
  recordGoalCreated(ownerId: string, goalId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: GoalEventType.GOAL_CREATED,
      entityType: EntityType.GOAL,
      entityId: goalId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a goal progress changed event.
   */
  recordGoalProgressChanged(
    ownerId: string,
    goalId: string,
    previousProgress: number,
    newProgress: number,
    manualProgress?: boolean
  ) {
    const metadata: GoalProgressChangedMetadata = {
      previousProgress,
      newProgress,
      manualProgress,
    };

    return this.recorder.recordEvent({
      ownerId,
      eventType: GoalEventType.GOAL_PROGRESS_CHANGED,
      entityType: EntityType.GOAL,
      entityId: goalId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a goal completed event.
   */
  recordGoalCompleted(ownerId: string, goalId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: GoalEventType.GOAL_COMPLETED,
      entityType: EntityType.GOAL,
      entityId: goalId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a goal paused event.
   */
  recordGoalPaused(ownerId: string, goalId: string, reason?: string) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: GoalEventType.GOAL_PAUSED,
      entityType: EntityType.GOAL,
      entityId: goalId,
      source: EventSource.USER,
      metadata: reason ? { reason } : undefined,
    });
  }
}
