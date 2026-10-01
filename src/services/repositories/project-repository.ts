import Database from 'better-sqlite3';
import { BaseRepository } from './base-repository.js';
import { nowMs, newId, type ProjectRecord } from './repository-types.js';

export class ProjectRepository extends BaseRepository<ProjectRecord> {
  constructor(db: Database.Database) {
    super(db, 'projects');
  }

  create(input: Omit<ProjectRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): ProjectRecord {
    const now = nowMs();
    const item: ProjectRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      goalId: input.goalId ?? null,
      title: input.title,
      description: input.description ?? null,
      status: input.status,
      priority: input.priority ?? 0,
      startDate: input.startDate ?? null,
      targetDate: input.targetDate ?? null,
      completedAt: input.completedAt ?? null,
      progressMode: input.progressMode ?? 'CALCULATED',
      manualProgress: input.manualProgress ?? null,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db.prepare(`
      INSERT INTO projects (
        id, owner_id, goal_id, title, description, status, priority,
        start_date, target_date, completed_at, progress_mode,
        manual_progress, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      item.id,
      item.ownerId,
      item.goalId,
      item.title,
      item.description,
      item.status,
      item.priority,
      item.startDate,
      item.targetDate,
      item.completedAt,
      item.progressMode,
      item.manualProgress,
      item.createdAt,
      item.updatedAt,
      item.archivedAt
    );

    return item;
  }

  update(id: string, changes: Partial<ProjectRecord>): ProjectRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: ProjectRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db.prepare(`
      UPDATE projects SET
        goal_id = ?, title = ?, description = ?, status = ?, priority = ?,
        start_date = ?, target_date = ?, completed_at = ?,
        progress_mode = ?, manual_progress = ?,
        updated_at = ?, archived_at = ?
      WHERE id = ?
    `).run(
      next.goalId,
      next.title,
      next.description,
      next.status,
      next.priority,
      next.startDate,
      next.targetDate,
      next.completedAt,
      next.progressMode,
      next.manualProgress,
      next.updatedAt,
      next.archivedAt,
      id
    );

    return next;
  }

  findByStatus(ownerId: string, status: string): ProjectRecord[] {
    return this.db.prepare(`
      SELECT * FROM projects
      WHERE owner_id = ? AND status = ? AND archived_at IS NULL
      ORDER BY priority DESC, created_at DESC
    `).all(ownerId, status) as ProjectRecord[];
  }

  findActive(ownerId: string): ProjectRecord[] {
    return this.db.prepare(`
      SELECT * FROM projects
      WHERE owner_id = ? AND status IN ('ACTIVE', 'PLANNED')
      AND archived_at IS NULL
      ORDER BY priority DESC, created_at DESC
    `).all(ownerId) as ProjectRecord[];
  }

  findByGoal(ownerId: string, goalId: string): ProjectRecord[] {
    return this.db.prepare(`
      SELECT * FROM projects
      WHERE owner_id = ? AND goal_id = ? AND archived_at IS NULL
      ORDER BY priority DESC, created_at DESC
    `).all(ownerId, goalId) as ProjectRecord[];
  }
}
