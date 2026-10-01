import type Database from 'better-sqlite3';

import type { Habit } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class HabitRepository extends BaseRepository<Habit> {
  protected readonly tableName = 'habits';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Habit {
    return row as Habit;
  }

  create(habit: Habit): Habit {
    this.db
      .prepare(
        `
        INSERT INTO habits (
          id, owner_id, goal_id, title, description, status, target_count,
          preferred_time, duration_minutes, start_date, end_date,
          category_id, created_at, updated_at, archived_at
        ) VALUES (
          @id, @owner_id, @goal_id, @title, @description, @status, @target_count,
          @preferred_time, @duration_minutes, @start_date, @end_date,
          @category_id, @created_at, @updated_at, @archived_at
        )
        `
      )
      .run(habit);

    return habit;
  }

  update(id: string, updates: Partial<Habit>): Habit | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const merged: Habit = {
      ...existing,
      ...updates,
      updated_at: Date.now(),
    };

    this.db
      .prepare(
        `
        UPDATE habits SET
          goal_id = @goal_id,
          title = @title,
          description = @description,
          status = @status,
          target_count = @target_count,
          preferred_time = @preferred_time,
          duration_minutes = @duration_minutes,
          start_date = @start_date,
          end_date = @end_date,
          category_id = @category_id,
          updated_at = @updated_at,
          archived_at = @archived_at
        WHERE id = @id
        `
      )
      .run(merged);

    return merged;
  }
}
