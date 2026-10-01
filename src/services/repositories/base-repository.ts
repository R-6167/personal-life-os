import Database from 'better-sqlite3';

export abstract class BaseRepository<T extends { id: string; ownerId: string; updatedAt: number; createdAt: number }> {
  protected readonly db: Database.Database;
  protected readonly tableName: string;

  constructor(db: Database.Database, tableName: string) {
    this.db = db;
    this.tableName = tableName;
  }

  findById(id: string): T | null {
    const row = this.db.prepare(`SELECT * FROM ${this.tableName} WHERE id = ?`).get(id) as T | undefined;
    return row ?? null;
  }

  findByOwner(ownerId: string): T[] {
    const rows = this.db.prepare(`SELECT * FROM ${this.tableName} WHERE owner_id = ? ORDER BY created_at DESC`).all(ownerId) as T[];
    return rows;
  }

  list(ownerId: string, filters: Partial<T> = {}): T[] {
    const clauses: string[] = ['owner_id = ?'];
    const params: unknown[] = [ownerId];

    for (const [key, value] of Object.entries(filters)) {
      if (value === undefined || value === null) continue;
      clauses.push(`${this.toColumnName(key)} = ?`);
      params.push(value);
    }

    const sql = `SELECT * FROM ${this.tableName} WHERE ${clauses.join(' AND ')} ORDER BY created_at DESC`;
    return this.db.prepare(sql).all(...params) as T[];
  }

  archive(id: string): boolean {
    const result = this.db.prepare(`UPDATE ${this.tableName} SET archived_at = ?, updated_at = ? WHERE id = ?`).run(Date.now(), Date.now(), id);
    return (result.changes ?? 0) > 0;
  }

  remove(id: string): boolean {
    const result = this.db.prepare(`DELETE FROM ${this.tableName} WHERE id = ?`).run(id);
    return (result.changes ?? 0) > 0;
  }

  protected toColumnName(key: string): string {
    return key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
  }
}
