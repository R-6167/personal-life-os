import { createDatabase } from './index.js';

const db = createDatabase();

console.log('Database initialized successfully.');
console.log('Schema ready for Personal Life OS.');

db.close();
