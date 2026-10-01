import Database from 'better-sqlite3';
import { BaseRepository } from './base-repository.js';
import { nowMs, newId, type GoalRecord } from './repository-types.js';

export class GoalRepository extends BaseRepository<GoalRecord> {
  constructor(db: Database.Database) {
    super(db, 'goals');
  }

  create(input: Omit<GoalRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): GoalRecord {
    const now = nowMs();
    const item: GoalRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
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
      INSERT INTO goals (
        id, owner_id, title, description, status, priority,
        start_date, target_date, completed_at, progress_mode,
        manual_progress, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      item.id,
      item.ownerId,
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

  update(id: string, changes: Partial<GoalRecord>): GoalRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: GoalRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db.prepare(`
      UPDATE goals SET
        title = ?, description = ?, status = ?, priority = ?,
        start_date = ?, target_date = ?, completed_at = ?,
        progress_mode = ?, manual_progress = ?,
        updated_at = ?, archived_at = ?
      WHERE id = ?
    `).run(
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

  findByStatus(ownerId: string, status: string): GoalRecord[] {
    return this.db.prepare(`
      SELECT * FROM goals
      WHERE owner_id = ? AND status = ? AND archived_at IS NULL
      ORDER BY priority DESC, created_at DESC
    `).all(ownerId, status) as GoalRecord[];
  }

  findActive(ownerId: string): GoalRecord[] {
    return this.db.prepare(`
      SELECT * FROM goals
      WHERE owner_id = ? AND status IN ('ACTIVE', 'PAUSED')
      AND archived_at IS NULL
      ORDER BY priority DESC, created_at DESC
    `).all(ownerId) as GoalRecord[];
  }
}
