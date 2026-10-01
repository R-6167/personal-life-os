import type Database from 'better-sqlite3';

import type { Project } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class ProjectRepository extends BaseRepository<Project> {
  protected readonly tableName = 'projects';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Project {
    return row as Project;
  }

  create(project: Project): Project {
    this.db
      .prepare(
        `
        INSERT INTO projects (
          id, owner_id, goal_id, title, description, status,
          priority, start_date, target_date, completed_at, progress_mode,
          manual_progress, created_at, updated_at, archived_at
        ) VALUES (
          @id, @owner_id, @goal_id, @title, @description, @status,
          @priority, @start_date, @target_date, @completed_at, @progress_mode,
          @manual_progress, @created_at, @updated_at, @archived_at
        )
        `
      )
      .run(project);

    return project;
  }

  update(id: string, updates: Partial<Project>): Project | null {
    const existing = this.findById(id);
    if (!existing) return null;

    const merged: Project = {
      ...existing,
      ...updates,
      updated_at: Date.now(),
    };

    this.db
      .prepare(
        `
        UPDATE projects SET
          goal_id = @goal_id,
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
