import { createDatabase } from './db/index.js';

const db = createDatabase();

console.log('Personal Life OS booted.');
console.log('Database path:', db.name);

const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get() as { count: number };
console.log('Current users:', userCount.count);

db.close();
