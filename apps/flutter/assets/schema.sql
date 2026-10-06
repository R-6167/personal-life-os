-- Canonical SQLite schema for Ordin (contract-first).
-- Applied on create; additive migrations in database.dart for upgrades.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  kind TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  phone TEXT, email TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT, status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, title TEXT NOT NULL,
  status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS milestones (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, title TEXT NOT NULL,
  status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, goal_id TEXT,
  milestone_id TEXT, parent_task_id TEXT, title TEXT NOT NULL, description TEXT,
  status TEXT, priority INTEGER DEFAULT 0, due_at INTEGER,
  scheduled_start INTEGER, scheduled_end INTEGER, estimated_minutes INTEGER,
  completed_at INTEGER, archived_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS task_dependencies (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL, depends_on_task_id TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS task_recurrences (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL,
  frequency TEXT, interval INTEGER, interval_n INTEGER, days_of_week TEXT,
  start_date INTEGER, end_at INTEGER, until_at INTEGER, count INTEGER,
  by_month_days TEXT, enabled INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT, status TEXT, target_count INTEGER DEFAULT 1,
  start_date INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_schedules (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, frequency TEXT,
  interval INTEGER, days_of_week TEXT, created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS habit_occurrences (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL,
  status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  estimated_minutes INTEGER, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_steps (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, title TEXT NOT NULL,
  estimated_minutes INTEGER, sort_order INTEGER DEFAULT 0, created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS routine_schedules (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, frequency TEXT,
  interval INTEGER, days_of_week TEXT, created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS routine_occurrences (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL,
  status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  start_at INTEGER NOT NULL, end_at INTEGER NOT NULL, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS time_blocks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT, type TEXT,
  start_at INTEGER NOT NULL, end_at INTEGER NOT NULL, task_id TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reminders (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, message TEXT,
  trigger_at INTEGER NOT NULL, source_type TEXT, source_id TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT, content TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS entity_links (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
  from_type TEXT NOT NULL, from_id TEXT NOT NULL,
  to_type TEXT NOT NULL, to_id TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS financial_accounts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, type TEXT,
  current_balance_minor INTEGER DEFAULT 0, currency TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS income (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT, source TEXT,
  amount_minor INTEGER NOT NULL, currency TEXT, occurred_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT, category_id TEXT,
  description TEXT, amount_minor INTEGER NOT NULL, currency TEXT,
  occurred_at INTEGER NOT NULL, payment_method TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bills (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  expected_amount_minor INTEGER, currency TEXT, next_due_at INTEGER,
  frequency TEXT, interval INTEGER, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bill_occurrences (
  id TEXT PRIMARY KEY, bill_id TEXT NOT NULL, due_at INTEGER NOT NULL,
  expected_amount_minor INTEGER, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, service_name TEXT NOT NULL,
  amount_minor INTEGER, currency TEXT, frequency TEXT, interval INTEGER,
  next_renewal_at INTEGER, default_account_id TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, direction TEXT,
  principal_amount_minor INTEGER, remaining_amount_minor INTEGER, currency TEXT,
  status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debt_payments (
  id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL, account_id TEXT, expense_id TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS savings_goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  target_amount_minor INTEGER, current_amount_minor INTEGER DEFAULT 0,
  currency TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_contributions (
  id TEXT PRIMARY KEY, goal_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL, account_id TEXT, expense_id TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS practical_items (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  status TEXT, due_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  expires_at INTEGER, status TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_lists (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_items (
  id TEXT PRIMARY KEY, list_id TEXT NOT NULL, name TEXT NOT NULL,
  done INTEGER DEFAULT 0, created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, mood INTEGER, notes TEXT,
  occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, kind TEXT NOT NULL,
  value_real REAL, occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goal_reflections (
  id TEXT PRIMARY KEY, goal_id TEXT NOT NULL, content TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS budgets (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  category_id TEXT, amount_minor INTEGER, period TEXT, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
  event_type TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL,
  source TEXT, metadata TEXT, summary TEXT,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_activity_owner_occurred ON activity_events(owner_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_entity ON activity_events(entity_type, entity_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_event_type ON activity_events(event_type, occurred_at DESC);

CREATE TABLE IF NOT EXISTS app_usage_events (
  id TEXT PRIMARY KEY,
  owner_id TEXT,
  event_name TEXT NOT NULL,
  screen TEXT,
  props TEXT,
  occurred_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS error_logs (
  id TEXT PRIMARY KEY,
  owner_id TEXT,
  level TEXT NOT NULL DEFAULT 'ERROR',
  message TEXT NOT NULL,
  stack TEXT,
  context TEXT,
  occurred_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS feedback_items (
  id TEXT PRIMARY KEY,
  owner_id TEXT,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS work_sessions (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  task_id TEXT,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  status TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
