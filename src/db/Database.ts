import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEFAULT_DB_PATH = path.resolve(process.cwd(), 'data', 'personal-life-os.db');

export function createDatabase(dbPath = DEFAULT_DB_PATH): Database.Database {
  const directory = path.dirname(dbPath);
  if (!fs.existsSync(directory)) {
    fs.mkdirSync(directory, { recursive: true });
  }

  const database = new Database(dbPath);
  database.pragma('foreign_keys = ON');
  database.pragma('journal_mode = WAL');

  const schemaPath = path.join(path.dirname(fileURLToPath(import.meta.url)), 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  database.exec(schemaSql);

  return database;
}
