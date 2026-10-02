import Database from 'better-sqlite3';
import { EventBus } from '../../intelligence/event-bus.js';
import { TaskRepository } from '../repositories/task-repository.js';
import type { TaskRecord } from '../repositories/repository-types.js';
import { nowMs } from '../repositories/repository-types.js';

/**
 * TaskService — transactional domain operations for tasks.
 * Every state change updates the entity AND records an immutable ActivityEvent.
 */
export class TaskService {
  private readonly tasks: TaskRepository;
  private readonly bus: EventBus;

  constructor(db: Database.Database, bus?: EventBus) {
    this.tasks = new TaskRepository(db);
    this.bus = bus ?? new EventBus(db);
  }

  create(
    input: Omit<TaskRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & { id?: string }
  ): TaskRecord {
    return this.bus.transaction((bus) => {
      const task = this.tasks.create({
        ...input,
        status: input.status ?? 'INBOX',
        priority: input.priority ?? 0,
      });
      bus.task.recordTaskCreated(task.ownerId, task.id, { title: task.title });
      return task;
    });
  }

  start(taskId: string): TaskRecord {
    return this.bus.transaction((bus) => {
      const existing = this.tasks.findById(taskId);
      if (!existing) throw new Error(`Task not found: ${taskId}`);
      if (existing.status === 'COMPLETED') {
        throw new Error('Cannot start a completed task');
      }

      const updated = this.tasks.update(taskId, { status: 'IN_PROGRESS' });
      if (!updated) throw new Error(`Failed to update task: ${taskId}`);

      bus.task.recordTaskStarted(updated.ownerId, taskId, {
        previousStatus: existing.status,
      });
      return updated;
    });
  }

  complete(taskId: string, actualMinutes?: number): TaskRecord {
    return this.bus.transaction((bus) => {
      const existing = this.tasks.findById(taskId);
      if (!existing) throw new Error(`Task not found: ${taskId}`);

      const updated = this.tasks.update(taskId, {
        status: 'COMPLETED',
        completedAt: nowMs(),
        actualMinutes: actualMinutes ?? existing.actualMinutes ?? null,
      });
      if (!updated) throw new Error(`Failed to complete task: ${taskId}`);

      bus.task.recordTaskCompleted(
        updated.ownerId,
        taskId,
        existing.status,
        updated.actualMinutes ?? undefined,
        updated.estimatedMinutes ?? undefined
      );
      return updated;
    });
  }

  reopen(taskId: string): TaskRecord {
    return this.bus.transaction((bus) => {
      const existing = this.tasks.findById(taskId);
      if (!existing) throw new Error(`Task not found: ${taskId}`);

      const updated = this.tasks.update(taskId, {
        status: 'PLANNED',
        completedAt: null,
      });
      if (!updated) throw new Error(`Failed to reopen task: ${taskId}`);

      bus.task.recordTaskReopened(updated.ownerId, taskId, {
        previousStatus: existing.status,
      });
      return updated;
    });
  }

  cancel(taskId: string): TaskRecord {
    return this.bus.transaction((bus) => {
      const existing = this.tasks.findById(taskId);
      if (!existing) throw new Error(`Task not found: ${taskId}`);

      const updated = this.tasks.update(taskId, { status: 'CANCELLED' });
      if (!updated) throw new Error(`Failed to cancel task: ${taskId}`);

      bus.task.recordTaskCancelled(updated.ownerId, taskId, {
        previousStatus: existing.status,
      });
      return updated;
    });
  }

  findById(id: string): TaskRecord | null {
    return this.tasks.findById(id);
  }

  listByOwner(ownerId: string): TaskRecord[] {
    return this.tasks.findByOwner(ownerId);
  }

  listByStatus(ownerId: string, status: string): TaskRecord[] {
    return this.tasks.findByStatus(ownerId, status);
  }
}

export function createTaskService(db: Database.Database, bus?: EventBus): TaskService {
  return new TaskService(db, bus);
}
