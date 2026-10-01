import Database from 'better-sqlite3';
import { BaseRepository } from './base-repository.js';
import { nowMs, newId } from './repository-types.js';

export interface RoutineRecord {
  id: string;
  ownerId: string;
  goalId?: string | null;
  name: string;
  description?: string | null;
  status: string;
  estimatedMinutes?: number | null;
  createdAt: number;
  updatedAt: number;
  archivedAt?: number | null;
}

export class RoutineRepository extends BaseRepository<RoutineRecord> {
  constructor(db: Database.Database) {
    super(db, 'routines');
  }

  create(input: Omit<RoutineRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): RoutineRecord {
    const now = nowMs();
    const item: RoutineRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      goalId: input.goalId ?? null,
      name: input.name,
      description: input.description ?? null,
      status: input.status,
      estimatedMinutes: input.estimatedMinutes ?? null,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db.prepare(`
      INSERT INTO routines (
        id, owner_id, goal_id, name, description, status,
        estimated_minutes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      item.id,
      item.ownerId,
      item.goalId,
      item.name,
      item.description,
      item.status,
      item.estimatedMinutes,
      item.createdAt,
      item.updatedAt
    );

    return item;
  }

  update(id: string, changes: Partial<RoutineRecord>): RoutineRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: RoutineRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db.prepare(`
      UPDATE routines SET
        goal_id = ?, name = ?, description = ?, status = ?,
        estimated_minutes = ?, updated_at = ?
      WHERE id = ?
    `).run(
      next.goalId,
      next.name,
      next.description,
      next.status,
      next.estimatedMinutes,
      next.updatedAt,
      id
    );

    return next;
  }

  findByStatus(ownerId: string, status: string): RoutineRecord[] {
    return this.db.prepare(`
      SELECT * FROM routines
      WHERE owner_id = ? AND status = ? AND archived_at IS NULL
      ORDER BY created_at DESC
    `).all(ownerId, status) as RoutineRecord[];
  }
}
