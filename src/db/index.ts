import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function createDatabase(dbPath = './data/personal-life-os.db') {
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const db = new Database(dbPath);
  db.pragma('foreign_keys = ON');
  db.pragma('journal_mode = WAL');

  const schemaSql = fs.readFileSync(
    path.join(path.dirname(fileURLToPath(import.meta.url)), 'schema.sql'),
    'utf8'
  );

  db.exec(schemaSql);
  return db;
}
