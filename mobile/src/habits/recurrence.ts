import type { Db } from '../db/database';
import { DEFAULT_OWNER_ID, uid } from '../db/database';

export function startOfDay(ts: number = Date.now()): number {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

export function dayOfWeek(ts: number): number {
  return new Date(ts).getDay();
}

type HabitRow = {
  id: string;
  title: string;
  frequency: string;
  interval: number;
  days_of_week: string | null;
  target_minutes: number | null;
  created_at: number;
};

function parseDaysOfWeek(raw: string | null): number[] | null {
  if (!raw) return null;
  try {
    const arr = JSON.parse(raw);
    if (Array.isArray(arr)) return arr.map(Number).filter((n) => n >= 0 && n <= 6);
  } catch {
    /* ignore */
  }
  return null;
}

export function shouldOccurOn(habit: HabitRow, dayStart: number): boolean {
  const freq = (habit.frequency || 'DAILY').toUpperCase();
  const interval = Math.max(1, habit.interval || 1);
  const createdDay = startOfDay(habit.created_at);
  if (dayStart < createdDay) return false;

  const daysSinceCreate = Math.floor((dayStart - createdDay) / 86400000);

  if (freq === 'DAILY') {
    return daysSinceCreate % interval === 0;
  }

  if (freq === 'WEEKLY') {
    const days = parseDaysOfWeek(habit.days_of_week);
    const dow = dayOfWeek(dayStart);
    if (days && days.length > 0) {
      if (!days.includes(dow)) return false;
    }
    const weeksSince = Math.floor(daysSinceCreate / 7);
    return weeksSince % interval === 0;
  }

  if (freq === 'MONTHLY') {
    const created = new Date(createdDay);
    const target = new Date(dayStart);
    if (target.getDate() !== created.getDate()) return false;
    const months =
      (target.getFullYear() - created.getFullYear()) * 12 +
      (target.getMonth() - created.getMonth());
    return months >= 0 && months % interval === 0;
  }

  return daysSinceCreate % interval === 0;
}

export async function ensureHabitOccurrences(
  db: Db,
  options?: { daysAhead?: number }
): Promise<{ generated: number; missed: number }> {
  const today = startOfDay();
  const daysAhead = options?.daysAhead ?? 0;
  let generated = 0;
  let missed = 0;

  const miss = await db.runAsync(
    `UPDATE habit_occurrences
     SET status = 'MISSED', updated_at = ?
     WHERE owner_id = ?
       AND status = 'EXPECTED'
       AND scheduled_date < ?`,
    Date.now(),
    DEFAULT_OWNER_ID,
    today
  );
  missed = miss.changes ?? 0;

  const habits = await db.getAllAsync<HabitRow>(
    `SELECT id, title, frequency,
            COALESCE(interval, 1) AS interval,
            days_of_week,
            target_minutes,
            created_at
     FROM habits
     WHERE owner_id = ?
       AND status = 'ACTIVE'
       AND archived_at IS NULL`,
    DEFAULT_OWNER_ID
  );

  for (let offset = 0; offset <= daysAhead; offset++) {
    const dayStart = today + offset * 86400000;
    for (const habit of habits) {
      if (!shouldOccurOn(habit, dayStart)) continue;

      const existing = await db.getFirstAsync<{ id: string }>(
        `SELECT id FROM habit_occurrences
         WHERE habit_id = ? AND scheduled_date = ? LIMIT 1`,
        habit.id,
        dayStart
      );
      if (existing) continue;

      const now = Date.now();
      await db.runAsync(
        `INSERT INTO habit_occurrences
           (id, habit_id, owner_id, scheduled_date, status, target_minutes, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?, ?)`,
        uid('ho'),
        habit.id,
        DEFAULT_OWNER_ID,
        dayStart,
        habit.target_minutes,
        now,
        now
      );
      generated += 1;
    }
  }

  await db.runAsync(
    `INSERT OR REPLACE INTO app_meta (key, value) VALUES ('last_habit_generation', ?)`,
    String(today)
  );

  return { generated, missed };
}
