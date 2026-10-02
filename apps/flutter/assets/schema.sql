PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, display_name TEXT,
  timezone TEXT NOT NULL, locale TEXT NOT NULL DEFAULT 'en',
  currency TEXT NOT NULL DEFAULT 'KES', week_start_day INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY, owner_id TEXT, name TEXT NOT NULL, type TEXT NOT NULL,
  parent_category_id TEXT, icon TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  phone TEXT, email TEXT, company TEXT, relationship_type TEXT, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL, priority INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER, target_date INTEGER, completed_at INTEGER,
  progress_mode TEXT NOT NULL DEFAULT 'CALCULATED', manual_progress REAL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, title TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL, priority INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER, target_date INTEGER, completed_at INTEGER,
  progress_mode TEXT NOT NULL DEFAULT 'CALCULATED', manual_progress REAL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS milestones (
  id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER, target_date INTEGER, completed_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, milestone_id TEXT, goal_id TEXT, parent_task_id TEXT,
  title TEXT NOT NULL, description TEXT, status TEXT NOT NULL, priority INTEGER NOT NULL DEFAULT 0,
  scheduled_start INTEGER, scheduled_end INTEGER, due_at INTEGER,
  estimated_minutes INTEGER, actual_minutes INTEGER, completed_at INTEGER, category_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS task_dependencies (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL, depends_on_task_id TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'BLOCKED_BY', created_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY(depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  UNIQUE(task_id, depends_on_task_id)
);

CREATE TABLE IF NOT EXISTS task_recurrences (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL, frequency TEXT NOT NULL,
  interval_n INTEGER NOT NULL DEFAULT 1, days_of_week TEXT, day_of_month INTEGER,
  month_of_year INTEGER, start_date INTEGER NOT NULL, end_date INTEGER,
  timezone TEXT, enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, title TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL, target_count INTEGER NOT NULL DEFAULT 1,
  preferred_time INTEGER, duration_minutes INTEGER, start_date INTEGER NOT NULL, end_date INTEGER, category_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_schedules (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, frequency TEXT NOT NULL,
  interval_n INTEGER NOT NULL DEFAULT 1, days_of_week TEXT, times_per_day INTEGER DEFAULT 1,
  preferred_time INTEGER, start_date INTEGER NOT NULL, end_date INTEGER, timezone TEXT,
  enabled INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_occurrences (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL, scheduled_time INTEGER,
  status TEXT NOT NULL, completed_at INTEGER, skipped_at INTEGER,
  actual_duration_minutes INTEGER, reason TEXT, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, name TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL, estimated_minutes INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_steps (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
  position INTEGER NOT NULL, task_id TEXT, habit_id TEXT, estimated_minutes INTEGER,
  optional INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_schedules (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, frequency TEXT NOT NULL,
  days_of_week TEXT, preferred_time INTEGER, timezone TEXT, enabled INTEGER NOT NULL DEFAULT 1,
  start_date INTEGER NOT NULL, end_date INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_occurrences (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL, scheduled_time INTEGER,
  status TEXT NOT NULL, started_at INTEGER, completed_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
  start_at INTEGER NOT NULL, end_at INTEGER NOT NULL, timezone TEXT, location TEXT,
  status TEXT NOT NULL DEFAULT 'SCHEDULED', project_id TEXT, goal_id TEXT, person_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS time_blocks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  start_at INTEGER NOT NULL, end_at INTEGER NOT NULL, type TEXT NOT NULL,
  task_id TEXT, project_id TEXT, habit_id TEXT, routine_id TEXT, event_id TEXT,
  status TEXT NOT NULL DEFAULT 'PLANNED', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reminders (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, message TEXT,
  trigger_at INTEGER NOT NULL, repeat_rule TEXT, source_type TEXT, source_id TEXT,
  status TEXT NOT NULL DEFAULT 'PENDING', notification_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT, content TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS entity_links (
  id TEXT PRIMARY KEY, source_type TEXT NOT NULL, source_id TEXT NOT NULL,
  target_type TEXT NOT NULL, target_id TEXT NOT NULL, relationship_type TEXT,
  created_at INTEGER NOT NULL,
  UNIQUE(source_type, source_id, target_type, target_id, relationship_type)
);

CREATE TABLE IF NOT EXISTS financial_accounts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, type TEXT NOT NULL,
  currency TEXT NOT NULL, current_balance_minor INTEGER, institution TEXT,
  account_identifier TEXT, is_tracked INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS income (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT, category_id TEXT,
  source TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, description TEXT, project_id TEXT, goal_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT, category_id TEXT,
  merchant TEXT, description TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, payment_method TEXT, project_id TEXT, goal_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bills (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, provider TEXT, description TEXT,
  expected_amount_minor INTEGER, currency TEXT NOT NULL, frequency TEXT, next_due_at INTEGER,
  status TEXT NOT NULL, category_id TEXT, default_account_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bill_occurrences (
  id TEXT PRIMARY KEY, bill_id TEXT NOT NULL, period_start INTEGER, period_end INTEGER,
  due_at INTEGER NOT NULL, expected_amount_minor INTEGER, actual_amount_minor INTEGER,
  status TEXT NOT NULL, paid_at INTEGER, expense_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, service_name TEXT NOT NULL, description TEXT,
  provider TEXT, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  billing_frequency TEXT, next_renewal_at INTEGER, payment_method TEXT,
  status TEXT NOT NULL, category_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, cancelled_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, person_id TEXT, direction TEXT NOT NULL,
  title TEXT NOT NULL, description TEXT, original_amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL, remaining_amount_minor INTEGER NOT NULL, due_at INTEGER, status TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debt_payments (
  id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  paid_at INTEGER NOT NULL, account_id TEXT, note TEXT, expense_id TEXT, income_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(debt_id) REFERENCES debts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, name TEXT NOT NULL,
  target_amount_minor INTEGER NOT NULL, currency TEXT NOT NULL, target_date INTEGER,
  current_amount_minor INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_contributions (
  id TEXT PRIMARY KEY, savings_goal_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL, account_id TEXT, occurred_at INTEGER NOT NULL, note TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(savings_goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS practical_items (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT, status TEXT NOT NULL, due_at INTEGER, expires_at INTEGER,
  person_id TEXT, location TEXT, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL, document_type TEXT NOT NULL,
  document_number TEXT, issued_at INTEGER, expires_at INTEGER, issuer TEXT,
  file_reference TEXT, notes TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_lists (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, status TEXT NOT NULL,
  created_at INTEGER NOT NULL, completed_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_items (
  id TEXT PRIMARY KEY, shopping_list_id TEXT NOT NULL, name TEXT NOT NULL,
  quantity TEXT, estimated_price_minor INTEGER, actual_price_minor INTEGER,
  category TEXT, purchased INTEGER NOT NULL DEFAULT 0, purchased_at INTEGER, expense_id TEXT,
  FOREIGN KEY(shopping_list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, source TEXT NOT NULL,
  external_id TEXT, metadata TEXT,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tasks_owner ON tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_bills_owner ON bills(owner_id);
CREATE INDEX IF NOT EXISTS idx_calendar_start ON calendar_events(start_at);
CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_at);
CREATE INDEX IF NOT EXISTS idx_activity_owner ON activity_events(owner_id);
