import * as SQLite from 'expo-sqlite';
import { DEFAULT_OWNER_ID, SCHEMA_SQL } from './schema';

export type Db = SQLite.SQLiteDatabase;

let dbPromise: Promise<Db> | null = null;

function uid(prefix: string): string {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36).slice(-4)}`;
}

function startOfToday(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function hoursFromNow(h: number): number {
  return Date.now() + h * 60 * 60 * 1000;
}

function daysFromNow(d: number): number {
  return Date.now() + d * 24 * 60 * 60 * 1000;
}

async function seedIfEmpty(db: Db): Promise<void> {
  const row = await db.getFirstAsync<{ c: number }>('SELECT COUNT(*) as c FROM users');
  if (row && row.c > 0) return;

  const now = Date.now();
  await db.runAsync(
    `INSERT INTO users (id, name, timezone, locale, currency, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    DEFAULT_OWNER_ID,
    'Local User',
    'Africa/Nairobi',
    'en',
    'KES',
    now,
    now
  );

  const goalId = uid('goal');
  await db.runAsync(
    `INSERT INTO goals (id, owner_id, title, description, status, priority, target_date, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'ACTIVE', 2, ?, ?, ?)`,
    goalId,
    DEFAULT_OWNER_ID,
    'Launch Personal Life OS',
    'Ship a working offline life manager for Android',
    daysFromNow(90),
    now,
    now
  );

  const projectId = uid('proj');
  await db.runAsync(
    `INSERT INTO projects (id, owner_id, goal_id, title, description, status, priority, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'ACTIVE', 2, ?, ?)`,
    projectId,
    DEFAULT_OWNER_ID,
    goalId,
    'Personal Life OS',
    'Domain layer + mobile shell',
    now,
    now
  );

  const projectHome = uid('proj');
  await db.runAsync(
    `INSERT INTO projects (id, owner_id, goal_id, title, status, priority, created_at, updated_at)
     VALUES (?, ?, NULL, 'Home', 'ACTIVE', 0, ?, ?)`,
    projectHome,
    DEFAULT_OWNER_ID,
    now,
    now
  );

  const tasks = [
    ['Ship domain layer', 'Wire transactional services', 'IN_PROGRESS', 2, hoursFromNow(4), 90, projectId],
    ['Review electricity bill', null, 'PLANNED', 1, hoursFromNow(8), 15, projectHome],
    ['Call John about project kickoff', null, 'INBOX', 0, daysFromNow(1), 20, null],
    ['Draft weekly review notes', null, 'WAITING', 0, daysFromNow(-1), 30, projectId],
  ] as const;

  for (const [title, desc, status, priority, due, mins, proj] of tasks) {
    await db.runAsync(
      `INSERT INTO tasks (id, owner_id, project_id, title, description, status, priority, due_at, estimated_minutes, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      uid('task'),
      DEFAULT_OWNER_ID,
      proj,
      title,
      desc,
      status,
      priority,
      due,
      mins,
      now,
      now
    );
  }

  const habits = [
    ['Exercise', 30],
    ['Read 20 pages', 25],
    ['Drink water (morning)', 5],
  ] as const;

  for (let i = 0; i < habits.length; i++) {
    const [title, mins] = habits[i];
    const habitId = uid('habit');
    await db.runAsync(
      `INSERT INTO habits (id, owner_id, title, status, target_minutes, frequency, created_at, updated_at)
       VALUES (?, ?, ?, 'ACTIVE', ?, 'DAILY', ?, ?)`,
      habitId,
      DEFAULT_OWNER_ID,
      title,
      mins,
      now,
      now
    );
    const status = i === 2 ? 'COMPLETED' : 'EXPECTED';
    await db.runAsync(
      `INSERT INTO habit_occurrences (id, habit_id, owner_id, scheduled_date, status, target_minutes, completed_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      uid('ho'),
      habitId,
      DEFAULT_OWNER_ID,
      startOfToday(),
      status,
      mins,
      status === 'COMPLETED' ? now - 45 * 60 * 1000 : null,
      now,
      now
    );
  }

  const mpesa = uid('acc');
  await db.runAsync(
    `INSERT INTO financial_accounts (id, owner_id, name, type, currency, current_balance_minor, created_at, updated_at)
     VALUES (?, ?, 'M-Pesa', 'MOBILE_MONEY', 'KES', 5000000, ?, ?)`,
    mpesa,
    DEFAULT_OWNER_ID,
    now,
    now
  );
  await db.runAsync(
    `INSERT INTO financial_accounts (id, owner_id, name, type, currency, current_balance_minor, created_at, updated_at)
     VALUES (?, ?, 'Cash wallet', 'CASH', 'KES', 250000, ?, ?)`,
    uid('acc'),
    DEFAULT_OWNER_ID,
    now,
    now
  );

  const billElec = uid('bill');
  await db.runAsync(
    `INSERT INTO bills (id, owner_id, name, provider, expected_amount_minor, currency, status, created_at, updated_at)
     VALUES (?, ?, 'Electricity', 'Kenya Power', 350000, 'KES', 'ACTIVE', ?, ?)`,
    billElec,
    DEFAULT_OWNER_ID,
    now,
    now
  );
  await db.runAsync(
    `INSERT INTO bill_occurrences (id, bill_id, owner_id, due_at, expected_amount_minor, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 350000, 'DUE', ?, ?)`,
    uid('bo'),
    billElec,
    DEFAULT_OWNER_ID,
    daysFromNow(1),
    now,
    now
  );

  const billNet = uid('bill');
  await db.runAsync(
    `INSERT INTO bills (id, owner_id, name, provider, expected_amount_minor, currency, status, created_at, updated_at)
     VALUES (?, ?, 'Internet', 'Safaricom', 450000, 'KES', 'ACTIVE', ?, ?)`,
    billNet,
    DEFAULT_OWNER_ID,
    now,
    now
  );
  await db.runAsync(
    `INSERT INTO bill_occurrences (id, bill_id, owner_id, due_at, expected_amount_minor, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 450000, 'UPCOMING', ?, ?)`,
    uid('bo'),
    billNet,
    DEFAULT_OWNER_ID,
    daysFromNow(5),
    now,
    now
  );

  await db.runAsync(
    `INSERT INTO expenses (id, owner_id, account_id, description, amount_minor, currency, merchant, occurred_at, created_at)
     VALUES (?, ?, ?, 'Groceries', 185000, 'KES', 'Carrefour', ?, ?)`,
    uid('exp'),
    DEFAULT_OWNER_ID,
    mpesa,
    daysFromNow(-1),
    now
  );
  await db.runAsync(
    `INSERT INTO expenses (id, owner_id, account_id, description, amount_minor, currency, merchant, occurred_at, created_at)
     VALUES (?, ?, ?, 'Fuel', 300000, 'KES', 'Shell', ?, ?)`,
    uid('exp'),
    DEFAULT_OWNER_ID,
    mpesa,
    daysFromNow(-2),
    now
  );

  await db.runAsync(
    `INSERT INTO activity_events (id, owner_id, event_type, entity_type, entity_id, occurred_at, recorded_at, source)
     VALUES (?, ?, 'HABIT_COMPLETED', 'HABIT', 'seed', ?, ?, 'APP')`,
    uid('act'),
    DEFAULT_OWNER_ID,
    now - 45 * 60 * 1000,
    now
  );
}

export async function getDatabase(): Promise<Db> {
  if (!dbPromise) {
    dbPromise = (async () => {
      const db = await SQLite.openDatabaseAsync('personal_life_os.db');
      await db.execAsync(SCHEMA_SQL);
      await seedIfEmpty(db);
      return db;
    })();
  }
  return dbPromise;
}

export { uid, DEFAULT_OWNER_ID };
