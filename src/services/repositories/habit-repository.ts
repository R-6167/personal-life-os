import Database from 'better-sqlite3';
import { BaseRepository } from './base-repository.js';
import { nowMs, newId, type HabitRecord } from './repository-types.js';

export class HabitRepository extends BaseRepository<HabitRecord> {
  constructor(db: Database.Database) {
    super(db, 'habits');
  }

  create(input: Omit<HabitRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): HabitRecord {
    const now = nowMs();
    const item: HabitRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      goalId: input.goalId ?? null,
      title: input.title,
      description: input.description ?? null,
      status: input.status,
      frequencyType: input.frequencyType ?? 'WEEKLY',
      targetCount: input.targetCount ?? 1,
      preferredTime: input.preferredTime ?? null,
      durationMinutes: input.durationMinutes ?? null,
      startDate: input.startDate,
      endDate: input.endDate ?? null,
      categoryId: input.categoryId ?? null,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db.prepare(`
      INSERT INTO habits (
        id, owner_id, goal_id, title, description, status, frequency_type,
        target_count, preferred_time, duration_minutes, start_date, end_date,
        category_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      item.id,
      item.ownerId,
      item.goalId,
      item.title,
      item.description,
      item.status,
      item.frequencyType,
      item.targetCount,
      item.preferredTime,
      item.durationMinutes,
      item.startDate,
      item.endDate,
      item.categoryId,
      item.createdAt,
      item.updatedAt,
      item.archivedAt
    );

    return item;
  }

  update(id: string, changes: Partial<HabitRecord>): HabitRecord | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const next: HabitRecord = {
      ...existing,
      ...changes,
      updatedAt: nowMs(),
    };

    this.db.prepare(`
      UPDATE habits SET
        goal_id = ?, title = ?, description = ?, status = ?, frequency_type = ?,
        target_count = ?, preferred_time = ?, duration_minutes = ?, start_date = ?,
        end_date = ?, category_id = ?, updated_at = ?, archived_at = ?
      WHERE id = ?
    `).run(
      next.goalId,
      next.title,
      next.description,
      next.status,
      next.frequencyType,
      next.targetCount,
      next.preferredTime,
      next.durationMinutes,
      next.startDate,
      next.endDate,
      next.categoryId,
      next.updatedAt,
      next.archivedAt,
      id
    );

    return next;
  }

  findDueToday(ownerId: string, today: number): HabitRecord[] {
    return this.db.prepare(`
      SELECT * FROM habits
      WHERE owner_id = ? AND status NOT IN ('COMPLETED', 'ARCHIVED', 'CANCELLED')
      AND start_date <= ?
      ORDER BY created_at DESC
    `).all(ownerId, today) as HabitRecord[];
  }
}
