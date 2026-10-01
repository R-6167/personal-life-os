-- Additive recurrence tables. Kept separate so existing local databases can be upgraded safely.
CREATE TABLE IF NOT EXISTS task_occurrences (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  scheduled_date INTEGER NOT NULL,
  scheduled_time INTEGER,
  status TEXT NOT NULL,
  completed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  UNIQUE(task_id, scheduled_date, scheduled_time)
);
CREATE INDEX IF NOT EXISTS idx_task_occurrences_date ON task_occurrences(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_task_occurrences_task ON task_occurrences(task_id);

CREATE TABLE IF NOT EXISTS task_recurrences (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  frequency TEXT NOT NULL,
  interval_value INTEGER NOT NULL DEFAULT 1,
  days_of_week TEXT,
  day_of_month INTEGER,
  start_date INTEGER NOT NULL,
  end_date INTEGER,
  timezone TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_schedules (
  id TEXT PRIMARY KEY,
  habit_id TEXT NOT NULL,
  frequency TEXT NOT NULL,
  interval_value INTEGER NOT NULL DEFAULT 1,
  days_of_week TEXT,
  times_per_day INTEGER NOT NULL DEFAULT 1,
  preferred_time INTEGER,
  start_date INTEGER NOT NULL,
  end_date INTEGER,
  timezone TEXT NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);
