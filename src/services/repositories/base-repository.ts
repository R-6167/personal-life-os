import Database from 'better-sqlite3';

function snakeToCamelKey(key: string): string {
  return key.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
}

/** Convert a SQLite row (snake_case) into a camelCase record. */
export function mapRow<T>(row: Record<string, unknown> | undefined | null): T | null {
  if (!row) return null;
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) {
    out[snakeToCamelKey(key)] = value;
  }
  return out as T;
}

export function mapRows<T>(rows: Record<string, unknown>[]): T[] {
  return rows.map((row) => mapRow<T>(row)!);
}

export abstract class BaseRepository<
  T extends { id: string; ownerId: string; updatedAt: number; createdAt: number },
> {
  protected readonly db: Database.Database;
  protected readonly tableName: string;

  constructor(db: Database.Database, tableName: string) {
    this.db = db;
    this.tableName = tableName;
  }

  findById(id: string): T | null {
    const row = this.db
      .prepare(`SELECT * FROM ${this.tableName} WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;
    return mapRow<T>(row);
  }

  findByOwner(ownerId: string): T[] {
    const rows = this.db
      .prepare(`SELECT * FROM ${this.tableName} WHERE owner_id = ? ORDER BY created_at DESC`)
      .all(ownerId) as Record<string, unknown>[];
    return mapRows<T>(rows);
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
    const rows = this.db.prepare(sql).all(...params) as Record<string, unknown>[];
    return mapRows<T>(rows);
  }

  archive(id: string): boolean {
    const result = this.db
      .prepare(`UPDATE ${this.tableName} SET archived_at = ?, updated_at = ? WHERE id = ?`)
      .run(Date.now(), Date.now(), id);
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
