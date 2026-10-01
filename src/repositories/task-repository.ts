import type Database from 'better-sqlite3';

import type { Goal, Task, TaskStatus } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class TaskRepository extends BaseRepository<Task> {
  protected readonly tableName = 'tasks';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Task {
    return row as Task;
  }

  create(task: Task): Task {
    this.db
      .prepare(
        `
        INSERT INTO tasks (
          id, owner_id, project_id, milestone_id, goal_id, parent_task_id,
          title, description, status, priority, scheduled_start, scheduled_end,
          due_at, estimated_minutes, actual_minutes, completed_at, category_id,
          created_at, updated_at, archived_at
        ) VALUES (
          @id, @owner_id, @project_id, @milestone_id, @goal_id, @parent_task_id,
          @title, @description, @status, @priority, @scheduled_start, @scheduled_end,
          @due_at, @estimated_minutes, @actual_minutes, @completed_at, @category_id,
          @created_at, @updated_at, @archived_at
        )
        `
      )
      .run(task);

    return task;
  }

  update(id: string, updates: Partial<Task>): Task | null {
    const existing = this.findById(id);
    if (!existing) {
      return null;
    }

    const merged: Task = {
      ...existing,
      ...updates,
      updated_at: Date.now(),
    };

    this.db
      .prepare(
        `
        UPDATE tasks SET
          project_id = @project_id,
          milestone_id = @milestone_id,
          goal_id = @goal_id,
          parent_task_id = @parent_task_id,
          title = @title,
          description = @description,
          status = @status,
          priority = @priority,
          scheduled_start = @scheduled_start,
          scheduled_end = @scheduled_end,
          due_at = @due_at,
          estimated_minutes = @estimated_minutes,
          actual_minutes = @actual_minutes,
          completed_at = @completed_at,
          category_id = @category_id,
          updated_at = @updated_at,
          archived_at = @archived_at
        WHERE id = @id
        `
      )
      .run(merged);

    return merged;
  }

  listActiveByOwner(ownerId: string): Task[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM tasks WHERE owner_id = ? AND status != 'COMPLETED' AND status != 'CANCELLED' ORDER BY due_at ASC NULLS LAST`
      )
      .all(ownerId) as Record<string, unknown>[];

    return rows.map((row) => this.toModel(row));
  }

  listOverdue(ownerId: string, now: number): Task[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM tasks WHERE owner_id = ? AND status NOT IN ('COMPLETED', 'CANCELLED') AND due_at < ? ORDER BY due_at ASC`
      )
      .all(ownerId, now) as Record<string, unknown>[];

    return rows.map((row) => this.toModel(row));
  }

  completeTask(taskId: string): Task | null {
    return this.update(taskId, {
      status: 'COMPLETED',
      completed_at: Date.now(),
    });
  }

  reopenTask(taskId: string): Task | null {
    return this.update(taskId, {
      status: 'INBOX',
      completed_at: null,
    });
  }
}

export class GoalRepository extends BaseRepository<Goal> {
  protected readonly tableName = 'goals';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Goal {
    return row as Goal;
  }

  create(goal: Goal): Goal {
    this.db
      .prepare(
        `
        INSERT INTO goals (
          id, owner_id, title, description, status, priority,
          start_date, target_date, completed_at, progress_mode,
          manual_progress, created_at, updated_at, archived_at
        ) VALUES (
          @id, @owner_id, @title, @description, @status, @priority,
          @start_date, @target_date, @completed_at, @progress_mode,
          @manual_progress, @created_at, @updated_at, @archived_at
        )
        `
      )
      .run(goal);

    return goal;
  }

  update(id: string, updates: Partial<Goal>): Goal | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const merged: Goal = {
      ...existing,
      ...updates,
      updated_at: Date.now(),
    };

    this.db
      .prepare(
        `
        UPDATE goals SET
          title = @title,
          description = @description,
          status = @status,
          priority = @priority,
          start_date = @start_date,
          target_date = @target_date,
          completed_at = @completed_at,
          progress_mode = @progress_mode,
          manual_progress = @manual_progress,
          updated_at = @updated_at,
          archived_at = @archived_at
        WHERE id = @id
        `
      )
      .run(merged);

    return merged;
  }
}
