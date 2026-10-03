-- Personal Life OS schema (Flutter asset). Idempotent CREATE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  name TEXT,
  currency TEXT NOT NULL DEFAULT 'KES',
  week_start_day INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  kind TEXT NOT NULL, color TEXT, icon TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  phone TEXT, email TEXT, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT, status TEXT NOT NULL DEFAULT 'ACTIVE',
  target_date INTEGER, progress REAL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, goal_id TEXT, title TEXT NOT NULL,
  description TEXT, status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS milestones (
  id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PLANNED', position INTEGER DEFAULT 0,
  completed_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, goal_id TEXT,
  milestone_id TEXT, title TEXT NOT NULL, description TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN', priority INTEGER DEFAULT 0,
  due_at INTEGER, scheduled_start INTEGER, scheduled_end INTEGER,
  estimated_minutes INTEGER, completed_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS task_dependencies (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL, depends_on_task_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY(depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS task_recurrences (
  id TEXT PRIMARY KEY, task_id TEXT NOT NULL, frequency TEXT NOT NULL,
  interval INTEGER DEFAULT 1, days_of_week TEXT, end_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT, status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_schedules (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, frequency TEXT NOT NULL DEFAULT 'DAILY',
  days_of_week TEXT, target_count INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS habit_occurrences (
  id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'EXPECTED', completed_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_steps (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, title TEXT NOT NULL,
  position INTEGER DEFAULT 0, estimated_minutes INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_schedules (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, frequency TEXT NOT NULL DEFAULT 'DAILY',
  days_of_week TEXT, preferred_time TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routine_occurrences (
  id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, scheduled_date INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'EXPECTED', completed_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  start_at INTEGER NOT NULL, end_at INTEGER, all_day INTEGER DEFAULT 0,
  location TEXT, notes TEXT, kind TEXT DEFAULT 'EVENT',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS time_blocks (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT,
  start_at INTEGER NOT NULL, end_at INTEGER NOT NULL,
  task_id TEXT, kind TEXT DEFAULT 'FOCUS',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reminders (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  message TEXT, trigger_at INTEGER NOT NULL,
  source_type TEXT, source_id TEXT, status TEXT NOT NULL DEFAULT 'PENDING',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, content TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS entity_links (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
  from_type TEXT NOT NULL, from_id TEXT NOT NULL,
  to_type TEXT NOT NULL, to_id TEXT NOT NULL,
  relation TEXT, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS financial_accounts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  type TEXT NOT NULL, currency TEXT NOT NULL DEFAULT 'KES',
  current_balance_minor INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS income (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT,
  source TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, category_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, account_id TEXT,
  description TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, category_id TEXT, merchant TEXT, payment_method TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bills (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  expected_amount_minor INTEGER, currency TEXT NOT NULL,
  frequency TEXT NOT NULL DEFAULT 'MONTHLY', next_due_at INTEGER,
  status TEXT NOT NULL DEFAULT 'ACTIVE', default_account_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bill_occurrences (
  id TEXT PRIMARY KEY, bill_id TEXT NOT NULL, due_at INTEGER NOT NULL,
  expected_amount_minor INTEGER, actual_amount_minor INTEGER,
  status TEXT NOT NULL DEFAULT 'UPCOMING', paid_at INTEGER, expense_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, service_name TEXT NOT NULL,
  amount_minor INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT 'KES',
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debts (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  direction TEXT NOT NULL, original_amount_minor INTEGER NOT NULL,
  remaining_amount_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'KES',
  status TEXT NOT NULL DEFAULT 'OPEN',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS debt_payments (
  id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL, account_id TEXT, expense_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(debt_id) REFERENCES debts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_goals (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  target_amount_minor INTEGER NOT NULL, current_amount_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'KES', status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_contributions (
  id TEXT PRIMARY KEY, goal_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL, account_id TEXT, expense_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS practical_items (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  kind TEXT, notes TEXT, status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, title TEXT NOT NULL,
  expires_at INTEGER, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_lists (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'OPEN',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shopping_items (
  id TEXT PRIMARY KEY, list_id TEXT NOT NULL, title TEXT NOT NULL,
  quantity TEXT, checked INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, day INTEGER NOT NULL,
  mood INTEGER, energy INTEGER, sleep_hours REAL, notes TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, metric_type TEXT NOT NULL,
  value REAL NOT NULL, unit TEXT, measured_at INTEGER NOT NULL,
  notes TEXT, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goal_reflections (
  id TEXT PRIMARY KEY, goal_id TEXT NOT NULL, content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS budgets (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  match_key TEXT, category_id TEXT, amount_minor INTEGER NOT NULL,
  period TEXT NOT NULL DEFAULT 'MONTHLY',
  alert_threshold REAL NOT NULL DEFAULT 0.8,
  currency TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
  event_type TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL,
  source TEXT, metadata TEXT,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

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
  kind TEXT NOT NULL DEFAULT 'FEEDBACK',
  title TEXT NOT NULL,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_owner ON tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_bills_owner ON bills(owner_id);
CREATE INDEX IF NOT EXISTS idx_calendar_start ON calendar_events(start_at);
CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_at);
CREATE INDEX IF NOT EXISTS idx_activity_owner ON activity_events(owner_id);
CREATE INDEX IF NOT EXISTS idx_wellness_day ON wellness_checkins(day);
CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON health_metrics(metric_type, measured_at);
CREATE INDEX IF NOT EXISTS idx_budgets_owner ON budgets(owner_id);
CREATE INDEX IF NOT EXISTS idx_usage_occurred ON app_usage_events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_errors_occurred ON error_logs(occurred_at);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback_items(status);
CREATE INDEX IF NOT EXISTS idx_expenses_occurred ON expenses(occurred_at);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_income_occurred ON income(occurred_at);
CREATE INDEX IF NOT EXISTS idx_habit_occ_habit ON habit_occurrences(habit_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_routine_occ_routine ON routine_occurrences(routine_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_bill_occ_status ON bill_occurrences(status, due_at);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_habits_status ON habits(status);
CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at);
