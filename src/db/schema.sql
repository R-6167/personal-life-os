PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  display_name TEXT,
  timezone TEXT NOT NULL,
  locale TEXT NOT NULL DEFAULT 'en',
  currency TEXT NOT NULL DEFAULT 'KES',
  week_start_day INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  owner_id TEXT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  parent_category_id TEXT,
  icon TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(parent_category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_categories_owner ON categories(owner_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER,
  target_date INTEGER,
  completed_at INTEGER,
  progress_mode TEXT NOT NULL DEFAULT 'CALCULATED',
  manual_progress REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  goal_id TEXT,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER,
  target_date INTEGER,
  completed_at INTEGER,
  progress_mode TEXT NOT NULL DEFAULT 'CALCULATED',
  manual_progress REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_goal ON projects(goal_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);

CREATE TABLE IF NOT EXISTS milestones (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  start_date INTEGER,
  target_date INTEGER,
  completed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  project_id TEXT,
  milestone_id TEXT,
  goal_id TEXT,
  parent_task_id TEXT,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  scheduled_start INTEGER,
  scheduled_end INTEGER,
  due_at INTEGER,
  estimated_minutes INTEGER,
  actual_minutes INTEGER,
  completed_at INTEGER,
  category_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(milestone_id) REFERENCES milestones(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL,
  FOREIGN KEY(parent_task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_owner ON tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_milestone ON tasks(milestone_id);
CREATE INDEX IF NOT EXISTS idx_tasks_goal ON tasks(goal_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_task_id);

CREATE TABLE IF NOT EXISTS task_dependencies (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  depends_on_task_id TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'BLOCKED_BY',
  created_at INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY(depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  UNIQUE(task_id, depends_on_task_id)
);

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  goal_id TEXT,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  target_count INTEGER NOT NULL DEFAULT 1,
  preferred_time INTEGER,
  duration_minutes INTEGER,
  start_date INTEGER NOT NULL,
  end_date INTEGER,
  category_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS habit_occurrences (
  id TEXT PRIMARY KEY,
  habit_id TEXT NOT NULL,
  scheduled_date INTEGER NOT NULL,
  scheduled_time INTEGER,
  status TEXT NOT NULL,
  completed_at INTEGER,
  skipped_at INTEGER,
  actual_duration_minutes INTEGER,
  reason TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE,
  UNIQUE(habit_id, scheduled_date, scheduled_time)
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  goal_id TEXT,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  estimated_minutes INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS routine_steps (
  id TEXT PRIMARY KEY,
  routine_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  position INTEGER NOT NULL,
  task_id TEXT,
  habit_id TEXT,
  estimated_minutes INTEGER,
  optional INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  company TEXT,
  relationship_type TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS financial_accounts (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  currency TEXT NOT NULL,
  current_balance REAL,
  institution TEXT,
  account_identifier TEXT,
  is_tracked INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS income (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  account_id TEXT,
  category_id TEXT,
  source TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  description TEXT,
  project_id TEXT,
  goal_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id) REFERENCES financial_accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  account_id TEXT,
  category_id TEXT,
  merchant TEXT,
  description TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  payment_method TEXT,
  project_id TEXT,
  goal_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id) REFERENCES financial_accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  title TEXT,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_events (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  recorded_at INTEGER NOT NULL,
  source TEXT NOT NULL,
  external_id TEXT,
  metadata TEXT,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(source, external_id)
);

CREATE INDEX IF NOT EXISTS idx_activity_owner_time ON activity_events(owner_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_activity_entity ON activity_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_type ON activity_events(event_type);
CREATE INDEX IF NOT EXISTS idx_activity_source ON activity_events(source);
CREATE INDEX IF NOT EXISTS idx_activity_external ON activity_events(source, external_id);

CREATE VIEW IF NOT EXISTS today_tasks AS
SELECT *
FROM tasks
WHERE status != 'COMPLETED'
  AND due_at IS NOT NULL;
