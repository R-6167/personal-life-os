import Database from 'better-sqlite3';
import { BaseRepository, mapRows } from './base-repository.js';
import { nowMs, newId, type TaskRecord } from './repository-types.js';

export class TaskRepository extends BaseRepository<TaskRecord> {
  constructor(db: Database.Database) {
    super(db, 'tasks');
  }

  create(input: Omit<TaskRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): TaskRecord {
    const now = nowMs();
    const item: TaskRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      projectId: input.projectId ?? null,
      milestoneId: input.milestoneId ?? null,
      goalId: input.goalId ?? null,
      parentTaskId: input.parentTaskId ?? null,
      title: input.title,
      description: input.description ?? null,
      status: input.status,
      priority: input.priority ?? 0,
      scheduledStart: input.scheduledStart ?? null,
      scheduledEnd: input.scheduledEnd ?? null,
      dueAt: input.dueAt ?? null,
      estimatedMinutes: input.estimatedMinutes ?? null,
      actualMinutes: input.actualMinutes ?? null,
      completedAt: input.completedAt ?? null,
      categoryId: input.categoryId ?? null,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db.prepare(`
      INSERT INTO tasks (
        id, owner_id, project_id, milestone_id, goal_id, parent_task_id,
        title, description, status, priority, scheduled_start, scheduled_end,
        due_at, estimated_minutes, actual_minutes, completed_at, category_id,
        created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      item.id,
      item.ownerId,
      item.projectId,
      item.milestoneId,
      item.goalId,
      item.parentTaskId,
      item.title,
      item.description,
      item.status,
      item.priority,
      item.scheduledStart,
      item.scheduledEnd,
      item.dueAt,
      item.estimatedMinutes,
      item.actualMinutes,
      item.completedAt,
      item.categoryId,
      item.createdAt,
      item.updatedAt,
      item.archivedAt
    );

    return item;
  }

  update(id: string, changes: Partial<TaskRecord>): TaskRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: TaskRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db.prepare(`
      UPDATE tasks SET
        project_id = ?, milestone_id = ?, goal_id = ?, parent_task_id = ?,
        title = ?, description = ?, status = ?, priority = ?,
        scheduled_start = ?, scheduled_end = ?, due_at = ?,
        estimated_minutes = ?, actual_minutes = ?, completed_at = ?,
        category_id = ?, updated_at = ?, archived_at = ?
      WHERE id = ?
    `).run(
      next.projectId,
      next.milestoneId,
      next.goalId,
      next.parentTaskId,
      next.title,
      next.description,
      next.status,
      next.priority,
      next.scheduledStart,
      next.scheduledEnd,
      next.dueAt,
      next.estimatedMinutes,
      next.actualMinutes,
      next.completedAt,
      next.categoryId,
      next.updatedAt,
      next.archivedAt,
      id
    );

    return next;
  }

  findByStatus(ownerId: string, status: string): TaskRecord[] {
    const rows = this.db.prepare(`SELECT * FROM tasks WHERE owner_id = ? AND status = ? ORDER BY created_at DESC`).all(ownerId, status) as Record<string, unknown>[];
    return mapRows<TaskRecord>(rows);
  }

  markCompleted(id: string): TaskRecord | null {
    return this.update(id, {
      status: 'COMPLETED',
      completedAt: nowMs(),
    });
  }
}
