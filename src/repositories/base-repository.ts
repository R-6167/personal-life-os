import type Database from 'better-sqlite3';

export abstract class BaseRepository<T extends { id: string }> {
  constructor(protected readonly db: Database.Database) {}

  protected abstract readonly tableName: string;

  protected abstract toModel(row: Record<string, unknown>): T;

  findById(id: string): T | null {
    const row = this.db
      .prepare(`SELECT * FROM ${this.tableName} WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;

    return row ? this.toModel(row) : null;
  }

  listByOwner(ownerId: string): T[] {
    const rows = this.db
      .prepare(`SELECT * FROM ${this.tableName} WHERE owner_id = ? ORDER BY created_at DESC`)
      .all(ownerId) as Record<string, unknown>[];

    return rows.map((row) => this.toModel(row));
  }

  listAll(): T[] {
    const rows = this.db
      .prepare(`SELECT * FROM ${this.tableName} ORDER BY created_at DESC`)
      .all() as Record<string, unknown>[];

    return rows.map((row) => this.toModel(row));
  }

  delete(id: string): boolean {
    const result = this.db
      .prepare(`DELETE FROM ${this.tableName} WHERE id = ?`)
      .run(id);

    return result.changes > 0;
  }
}
