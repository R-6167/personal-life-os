PRAGMA foreign_keys = ON;

-- =============================================================================
-- PERSONAL LIFE OS — Schema
-- Local-first SQLite. All timestamps are Unix milliseconds (INTEGER).
-- Monetary values are stored as INTEGER minor units (amount_minor, etc.).
-- Currency codes are ISO 4217 (e.g. KES, USD, EUR, JPY).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. IDENTITY
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  display_name    TEXT,
  timezone        TEXT NOT NULL,
  locale          TEXT NOT NULL DEFAULT 'en',
  currency        TEXT NOT NULL DEFAULT 'KES',  -- default / primary currency (ISO 4217)
  week_start_day  INTEGER NOT NULL DEFAULT 1,   -- 0=Sun … 6=Sat
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS people (
  id                 TEXT PRIMARY KEY,
  owner_id           TEXT NOT NULL,
  name               TEXT NOT NULL,
  phone              TEXT,
  email              TEXT,
  company            TEXT,
  relationship_type  TEXT,
  notes              TEXT,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  archived_at        INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_people_owner ON people(owner_id);

-- ---------------------------------------------------------------------------
-- 2. CATEGORIES (cross-domain)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
  id                  TEXT PRIMARY KEY,
  owner_id            TEXT,                 -- NULL = system category
  name                TEXT NOT NULL,
  type                TEXT NOT NULL,         -- TASK | EXPENSE | INCOME | HABIT | PROJECT | PRACTICAL | …
  parent_category_id  TEXT,
  icon                TEXT,
  created_at          INTEGER NOT NULL,
  updated_at          INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(parent_category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_categories_owner ON categories(owner_id);
CREATE INDEX IF NOT EXISTS idx_categories_type  ON categories(type);

-- ---------------------------------------------------------------------------
-- 3. GOALS / PROJECTS / MILESTONES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS goals (
  id               TEXT PRIMARY KEY,
  owner_id         TEXT NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  status           TEXT NOT NULL,            -- ACTIVE | PAUSED | COMPLETED | CANCELLED | ARCHIVED
  priority         INTEGER NOT NULL DEFAULT 0,
  start_date       INTEGER,
  target_date      INTEGER,
  completed_at     INTEGER,
  progress_mode    TEXT NOT NULL DEFAULT 'CALCULATED',  -- CALCULATED | MANUAL
  manual_progress  REAL,                    -- 0.0–1.0 when progress_mode = MANUAL
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  archived_at      INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_goals_owner  ON goals(owner_id);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);

CREATE TABLE IF NOT EXISTS projects (
  id               TEXT PRIMARY KEY,
  owner_id         TEXT NOT NULL,
  goal_id          TEXT,
  title            TEXT NOT NULL,
  description      TEXT,
  status           TEXT NOT NULL,            -- ACTIVE | PAUSED | COMPLETED | CANCELLED | ARCHIVED
  priority         INTEGER NOT NULL DEFAULT 0,
  start_date       INTEGER,
  target_date      INTEGER,
  completed_at     INTEGER,
  progress_mode    TEXT NOT NULL DEFAULT 'CALCULATED',
  manual_progress  REAL,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  archived_at      INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id)  REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_projects_owner  ON projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_goal   ON projects(goal_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);

CREATE TABLE IF NOT EXISTS milestones (
  id            TEXT PRIMARY KEY,
  project_id    TEXT NOT NULL,
  title         TEXT NOT NULL,
  description   TEXT,
  status        TEXT NOT NULL,              -- PLANNED | IN_PROGRESS | COMPLETED | CANCELLED
  position      INTEGER NOT NULL DEFAULT 0,
  start_date    INTEGER,
  target_date   INTEGER,
  completed_at  INTEGER,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_milestones_project ON milestones(project_id);

-- ---------------------------------------------------------------------------
-- 4. TASKS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tasks (
  id                 TEXT PRIMARY KEY,
  owner_id           TEXT NOT NULL,
  project_id         TEXT,
  milestone_id       TEXT,
  goal_id            TEXT,
  parent_task_id     TEXT,
  title              TEXT NOT NULL,
  description        TEXT,
  status             TEXT NOT NULL,          -- INBOX | PLANNED | IN_PROGRESS | WAITING | COMPLETED | CANCELLED
  priority           INTEGER NOT NULL DEFAULT 0,
  scheduled_start    INTEGER,
  scheduled_end      INTEGER,
  due_at             INTEGER,
  estimated_minutes  INTEGER,
  actual_minutes     INTEGER,
  completed_at       INTEGER,
  category_id        TEXT,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  archived_at        INTEGER,
  FOREIGN KEY(owner_id)       REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(project_id)     REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(milestone_id)   REFERENCES milestones(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id)        REFERENCES goals(id) ON DELETE SET NULL,
  FOREIGN KEY(parent_task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id)    REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_owner     ON tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project   ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_milestone ON tasks(milestone_id);
CREATE INDEX IF NOT EXISTS idx_tasks_goal      ON tasks(goal_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status    ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due       ON tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_tasks_parent    ON tasks(parent_task_id);

CREATE TABLE IF NOT EXISTS task_dependencies (
  id                  TEXT PRIMARY KEY,
  task_id             TEXT NOT NULL,
  depends_on_task_id  TEXT NOT NULL,
  type                TEXT NOT NULL DEFAULT 'BLOCKED_BY',  -- BLOCKED_BY | WAITING_FOR | RELATED_TO
  created_at          INTEGER NOT NULL,
  FOREIGN KEY(task_id)            REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY(depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  UNIQUE(task_id, depends_on_task_id)
);

CREATE TABLE IF NOT EXISTS task_recurrences (
  id            TEXT PRIMARY KEY,
  task_id       TEXT NOT NULL,
  frequency     TEXT NOT NULL,              -- DAILY | WEEKLY | MONTHLY | YEARLY
  interval      INTEGER NOT NULL DEFAULT 1,
  days_of_week  TEXT,                       -- JSON array e.g. [1,3,5] (Mon/Wed/Fri)
  day_of_month  INTEGER,
  month_of_year INTEGER,
  start_date    INTEGER NOT NULL,
  end_date      INTEGER,
  timezone      TEXT,
  enabled       INTEGER NOT NULL DEFAULT 1,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_recurrences_task ON task_recurrences(task_id);

-- ---------------------------------------------------------------------------
-- 5. HABITS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS habits (
  id                TEXT PRIMARY KEY,
  owner_id          TEXT NOT NULL,
  goal_id           TEXT,
  title             TEXT NOT NULL,
  description       TEXT,
  status            TEXT NOT NULL,          -- ACTIVE | PAUSED | ARCHIVED
  target_count      INTEGER NOT NULL DEFAULT 1,
  preferred_time    INTEGER,
  duration_minutes  INTEGER,
  start_date        INTEGER NOT NULL,
  end_date          INTEGER,
  category_id       TEXT,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  archived_at       INTEGER,
  FOREIGN KEY(owner_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id)     REFERENCES goals(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_habits_owner  ON habits(owner_id);
CREATE INDEX IF NOT EXISTS idx_habits_status ON habits(status);

CREATE TABLE IF NOT EXISTS habit_schedules (
  id             TEXT PRIMARY KEY,
  habit_id       TEXT NOT NULL,
  frequency      TEXT NOT NULL,            -- DAILY | WEEKLY | MONTHLY
  interval       INTEGER NOT NULL DEFAULT 1,
  days_of_week   TEXT,                     -- JSON array
  times_per_day  INTEGER DEFAULT 1,
  preferred_time INTEGER,
  start_date     INTEGER NOT NULL,
  end_date       INTEGER,
  timezone       TEXT,
  enabled        INTEGER NOT NULL DEFAULT 1,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_habit_schedules_habit ON habit_schedules(habit_id);

CREATE TABLE IF NOT EXISTS habit_occurrences (
  id                      TEXT PRIMARY KEY,
  habit_id                TEXT NOT NULL,
  scheduled_date          INTEGER NOT NULL,
  scheduled_time          INTEGER,
  status                  TEXT NOT NULL,      -- EXPECTED | COMPLETED | MISSED | SKIPPED | PARTIAL
  completed_at            INTEGER,
  skipped_at              INTEGER,
  actual_duration_minutes INTEGER,
  reason                  TEXT,
  notes                   TEXT,
  created_at              INTEGER NOT NULL,
  updated_at              INTEGER NOT NULL,
  FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE,
  UNIQUE(habit_id, scheduled_date, scheduled_time)
);

CREATE INDEX IF NOT EXISTS idx_habit_occurrences_habit  ON habit_occurrences(habit_id);
CREATE INDEX IF NOT EXISTS idx_habit_occurrences_date   ON habit_occurrences(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_habit_occurrences_status ON habit_occurrences(status);

-- ---------------------------------------------------------------------------
-- 6. ROUTINES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS routines (
  id                 TEXT PRIMARY KEY,
  owner_id           TEXT NOT NULL,
  goal_id            TEXT,
  name               TEXT NOT NULL,
  description        TEXT,
  status             TEXT NOT NULL,          -- ACTIVE | PAUSED | ARCHIVED
  estimated_minutes  INTEGER,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id)  REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_routines_owner ON routines(owner_id);

CREATE TABLE IF NOT EXISTS routine_steps (
  id                 TEXT PRIMARY KEY,
  routine_id         TEXT NOT NULL,
  title              TEXT NOT NULL,
  description        TEXT,
  position           INTEGER NOT NULL,
  task_id            TEXT,
  habit_id           TEXT,
  estimated_minutes  INTEGER,
  optional           INTEGER NOT NULL DEFAULT 0,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE,
  FOREIGN KEY(task_id)    REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY(habit_id)   REFERENCES habits(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_routine_steps_routine ON routine_steps(routine_id);

CREATE TABLE IF NOT EXISTS routine_schedules (
  id             TEXT PRIMARY KEY,
  routine_id     TEXT NOT NULL,
  frequency      TEXT NOT NULL,            -- DAILY | WEEKLY
  days_of_week   TEXT,
  preferred_time INTEGER,
  timezone       TEXT,
  enabled        INTEGER NOT NULL DEFAULT 1,
  start_date     INTEGER NOT NULL,
  end_date       INTEGER,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_routine_schedules_routine ON routine_schedules(routine_id);

CREATE TABLE IF NOT EXISTS routine_occurrences (
  id              TEXT PRIMARY KEY,
  routine_id      TEXT NOT NULL,
  scheduled_date  INTEGER NOT NULL,
  scheduled_time  INTEGER,
  status          TEXT NOT NULL,            -- EXPECTED | STARTED | COMPLETED | MISSED | SKIPPED
  started_at      INTEGER,
  completed_at    INTEGER,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_routine_occurrences_routine ON routine_occurrences(routine_id);
CREATE INDEX IF NOT EXISTS idx_routine_occurrences_date    ON routine_occurrences(scheduled_date);

-- ---------------------------------------------------------------------------
-- 7. CALENDAR / TIME BLOCKS / REMINDERS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS calendar_events (
  id             TEXT PRIMARY KEY,
  owner_id       TEXT NOT NULL,
  title          TEXT NOT NULL,
  description    TEXT,
  start_at       INTEGER NOT NULL,
  end_at         INTEGER NOT NULL,
  timezone       TEXT,
  location       TEXT,
  status         TEXT NOT NULL DEFAULT 'SCHEDULED',  -- SCHEDULED | COMPLETED | CANCELLED
  recurrence_id  TEXT,
  project_id     TEXT,
  goal_id        TEXT,
  person_id      TEXT,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  FOREIGN KEY(owner_id)   REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id)    REFERENCES goals(id) ON DELETE SET NULL,
  FOREIGN KEY(person_id)  REFERENCES people(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_calendar_events_owner  ON calendar_events(owner_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_start  ON calendar_events(start_at);
CREATE INDEX IF NOT EXISTS idx_calendar_events_status ON calendar_events(status);

CREATE TABLE IF NOT EXISTS time_blocks (
  id          TEXT PRIMARY KEY,
  owner_id    TEXT NOT NULL,
  title       TEXT NOT NULL,
  start_at    INTEGER NOT NULL,
  end_at      INTEGER NOT NULL,
  type        TEXT NOT NULL,                -- TASK | PROJECT_WORK | HABIT | ROUTINE | PERSONAL | BREAK | OTHER
  task_id     TEXT,
  project_id  TEXT,
  habit_id    TEXT,
  routine_id  TEXT,
  event_id    TEXT,
  status      TEXT NOT NULL DEFAULT 'PLANNED',  -- PLANNED | IN_PROGRESS | COMPLETED | CANCELLED
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  FOREIGN KEY(owner_id)   REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(task_id)    REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(habit_id)   REFERENCES habits(id) ON DELETE SET NULL,
  FOREIGN KEY(routine_id) REFERENCES routines(id) ON DELETE SET NULL,
  FOREIGN KEY(event_id)   REFERENCES calendar_events(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_time_blocks_owner ON time_blocks(owner_id);
CREATE INDEX IF NOT EXISTS idx_time_blocks_start ON time_blocks(start_at);
CREATE INDEX IF NOT EXISTS idx_time_blocks_type  ON time_blocks(type);

CREATE TABLE IF NOT EXISTS reminders (
  id               TEXT PRIMARY KEY,
  owner_id         TEXT NOT NULL,
  title            TEXT NOT NULL,
  message          TEXT,
  trigger_at       INTEGER NOT NULL,
  repeat_rule      TEXT,
  source_type      TEXT,                     -- TASK | BILL | HABIT | DOCUMENT | SUBSCRIPTION | …
  source_id        TEXT,
  status           TEXT NOT NULL DEFAULT 'PENDING',  -- PENDING | FIRED | DISMISSED | SNOOZED
  notification_id  TEXT,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reminders_owner   ON reminders(owner_id);
CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_at);
CREATE INDEX IF NOT EXISTS idx_reminders_status  ON reminders(status);
CREATE INDEX IF NOT EXISTS idx_reminders_source  ON reminders(source_type, source_id);

-- ---------------------------------------------------------------------------
-- 8. NOTES & GENERIC LINKS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notes (
  id          TEXT PRIMARY KEY,
  owner_id    TEXT NOT NULL,
  title       TEXT,
  content     TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notes_owner ON notes(owner_id);

CREATE TABLE IF NOT EXISTS entity_links (
  id                 TEXT PRIMARY KEY,
  source_type        TEXT NOT NULL,
  source_id          TEXT NOT NULL,
  target_type        TEXT NOT NULL,
  target_id          TEXT NOT NULL,
  relationship_type  TEXT,
  created_at         INTEGER NOT NULL,
  UNIQUE(source_type, source_id, target_type, target_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_entity_links_source ON entity_links(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_entity_links_target ON entity_links(target_type, target_id);

-- ---------------------------------------------------------------------------
-- 9. FINANCE — Accounts & Transactions (minor units)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS financial_accounts (
  id                    TEXT PRIMARY KEY,
  owner_id              TEXT NOT NULL,
  name                  TEXT NOT NULL,
  type                  TEXT NOT NULL,        -- CASH | BANK | MOBILE_MONEY | WALLET | SAVINGS | OTHER
  currency              TEXT NOT NULL,        -- ISO 4217
  current_balance_minor INTEGER,             -- cached; transaction history remains authoritative
  institution           TEXT,
  account_identifier    TEXT,
  is_tracked            INTEGER NOT NULL DEFAULT 1,
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL,
  archived_at           INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_financial_accounts_owner ON financial_accounts(owner_id);

CREATE TABLE IF NOT EXISTS income (
  id            TEXT PRIMARY KEY,
  owner_id      TEXT NOT NULL,
  account_id    TEXT,
  category_id   TEXT,
  source        TEXT NOT NULL,
  amount_minor  INTEGER NOT NULL,
  currency      TEXT NOT NULL,
  occurred_at   INTEGER NOT NULL,
  description   TEXT,
  project_id    TEXT,
  goal_id       TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  FOREIGN KEY(owner_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id)  REFERENCES financial_accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY(project_id)  REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id)     REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_income_owner    ON income(owner_id);
CREATE INDEX IF NOT EXISTS idx_income_occurred ON income(occurred_at);
CREATE INDEX IF NOT EXISTS idx_income_account  ON income(account_id);

CREATE TABLE IF NOT EXISTS expenses (
  id              TEXT PRIMARY KEY,
  owner_id        TEXT NOT NULL,
  account_id      TEXT,
  category_id     TEXT,
  merchant        TEXT,
  description     TEXT NOT NULL,
  amount_minor    INTEGER NOT NULL,
  currency        TEXT NOT NULL,
  occurred_at     INTEGER NOT NULL,
  payment_method  TEXT,
  project_id      TEXT,
  goal_id         TEXT,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  FOREIGN KEY(owner_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id)  REFERENCES financial_accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY(project_id)  REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY(goal_id)     REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_expenses_owner    ON expenses(owner_id);
CREATE INDEX IF NOT EXISTS idx_expenses_occurred ON expenses(occurred_at);
CREATE INDEX IF NOT EXISTS idx_expenses_account  ON expenses(account_id);

-- ---------------------------------------------------------------------------
-- 10. BILLS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bills (
  id                     TEXT PRIMARY KEY,
  owner_id               TEXT NOT NULL,
  name                   TEXT NOT NULL,
  provider               TEXT,
  description            TEXT,
  expected_amount_minor  INTEGER,
  currency               TEXT NOT NULL,
  frequency              TEXT NOT NULL,      -- MONTHLY | WEEKLY | YEARLY | CUSTOM
  next_due_at            INTEGER NOT NULL,
  status                 TEXT NOT NULL,      -- ACTIVE | PAUSED | CANCELLED
  category_id            TEXT,
  default_account_id     TEXT,
  created_at             INTEGER NOT NULL,
  updated_at             INTEGER NOT NULL,
  archived_at            INTEGER,
  FOREIGN KEY(owner_id)           REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(category_id)        REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY(default_account_id) REFERENCES financial_accounts(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_bills_owner  ON bills(owner_id);
CREATE INDEX IF NOT EXISTS idx_bills_due    ON bills(next_due_at);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);

CREATE TABLE IF NOT EXISTS bill_occurrences (
  id                     TEXT PRIMARY KEY,
  bill_id                TEXT NOT NULL,
  period_start           INTEGER,
  period_end             INTEGER,
  due_at                 INTEGER NOT NULL,
  expected_amount_minor  INTEGER,
  actual_amount_minor    INTEGER,
  status                 TEXT NOT NULL,      -- UPCOMING | DUE | OVERDUE | PAID | CANCELLED
  paid_at                INTEGER,
  expense_id             TEXT,
  created_at             INTEGER NOT NULL,
  updated_at             INTEGER NOT NULL,
  FOREIGN KEY(bill_id)    REFERENCES bills(id) ON DELETE CASCADE,
  FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_bill_occurrences_bill   ON bill_occurrences(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_occurrences_due    ON bill_occurrences(due_at);
CREATE INDEX IF NOT EXISTS idx_bill_occurrences_status ON bill_occurrences(status);

-- ---------------------------------------------------------------------------
-- 11. SUBSCRIPTIONS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS subscriptions (
  id                 TEXT PRIMARY KEY,
  owner_id           TEXT NOT NULL,
  service_name       TEXT NOT NULL,
  description        TEXT,
  provider           TEXT,
  amount_minor       INTEGER NOT NULL,
  currency           TEXT NOT NULL,
  billing_frequency  TEXT NOT NULL,
  next_renewal_at    INTEGER NOT NULL,
  payment_method     TEXT,
  status             TEXT NOT NULL,          -- ACTIVE | PAUSED | CANCELLED | EXPIRED
  category_id        TEXT,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  cancelled_at       INTEGER,
  FOREIGN KEY(owner_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_owner   ON subscriptions(owner_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status  ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_renewal ON subscriptions(next_renewal_at);

-- ---------------------------------------------------------------------------
-- 12. DEBTS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS debts (
  id                      TEXT PRIMARY KEY,
  owner_id                TEXT NOT NULL,
  person_id               TEXT,
  direction               TEXT NOT NULL,    -- OWED_BY_ME | OWED_TO_ME
  title                   TEXT NOT NULL,
  description             TEXT,
  original_amount_minor   INTEGER NOT NULL,
  currency                TEXT NOT NULL,
  remaining_amount_minor  INTEGER NOT NULL,
  due_at                  INTEGER,
  status                  TEXT NOT NULL,    -- ACTIVE | PAID | CANCELLED | WRITTEN_OFF
  created_at              INTEGER NOT NULL,
  updated_at              INTEGER NOT NULL,
  FOREIGN KEY(owner_id)  REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(person_id) REFERENCES people(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_debts_owner  ON debts(owner_id);
CREATE INDEX IF NOT EXISTS idx_debts_status ON debts(status);

CREATE TABLE IF NOT EXISTS debt_payments (
  id            TEXT PRIMARY KEY,
  debt_id       TEXT NOT NULL,
  amount_minor  INTEGER NOT NULL,
  currency      TEXT NOT NULL,
  paid_at       INTEGER NOT NULL,
  account_id    TEXT,
  note          TEXT,
  expense_id    TEXT,
  income_id     TEXT,
  created_at    INTEGER NOT NULL,
  FOREIGN KEY(debt_id)    REFERENCES debts(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id) REFERENCES financial_accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE SET NULL,
  FOREIGN KEY(income_id)  REFERENCES income(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_debt_payments_debt ON debt_payments(debt_id);

-- ---------------------------------------------------------------------------
-- 13. SAVINGS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS savings_goals (
  id                   TEXT PRIMARY KEY,
  owner_id             TEXT NOT NULL,
  goal_id              TEXT,
  name                 TEXT NOT NULL,
  target_amount_minor  INTEGER NOT NULL,
  currency             TEXT NOT NULL,
  target_date          INTEGER,
  current_amount_minor INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL,        -- ACTIVE | COMPLETED | CANCELLED | PAUSED
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(goal_id)  REFERENCES goals(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_savings_goals_owner  ON savings_goals(owner_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_status ON savings_goals(status);

CREATE TABLE IF NOT EXISTS savings_contributions (
  id               TEXT PRIMARY KEY,
  savings_goal_id  TEXT NOT NULL,
  amount_minor     INTEGER NOT NULL,
  currency         TEXT NOT NULL,
  account_id       TEXT,
  occurred_at      INTEGER NOT NULL,
  note             TEXT,
  created_at       INTEGER NOT NULL,
  FOREIGN KEY(savings_goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id)      REFERENCES financial_accounts(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_savings_contributions_goal ON savings_contributions(savings_goal_id);

-- ---------------------------------------------------------------------------
-- 14. PRACTICAL LIFE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS practical_items (
  id          TEXT PRIMARY KEY,
  owner_id    TEXT NOT NULL,
  type        TEXT NOT NULL,                -- DOCUMENT | RENEWAL | MAINTENANCE | HOUSEHOLD | VEHICLE | SHOPPING | OTHER
  title       TEXT NOT NULL,
  description TEXT,
  status      TEXT NOT NULL,
  due_at      INTEGER,
  expires_at  INTEGER,
  person_id   TEXT,
  location    TEXT,
  notes       TEXT,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  archived_at INTEGER,
  FOREIGN KEY(owner_id)  REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(person_id) REFERENCES people(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_practical_items_owner ON practical_items(owner_id);
CREATE INDEX IF NOT EXISTS idx_practical_items_type  ON practical_items(type);
CREATE INDEX IF NOT EXISTS idx_practical_items_due   ON practical_items(due_at);

CREATE TABLE IF NOT EXISTS documents (
  id               TEXT PRIMARY KEY,
  owner_id         TEXT NOT NULL,
  title            TEXT NOT NULL,
  document_type    TEXT NOT NULL,
  document_number  TEXT,
  issued_at        INTEGER,
  expires_at       INTEGER,
  issuer           TEXT,
  file_reference   TEXT,
  notes            TEXT,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_documents_owner   ON documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_expires ON documents(expires_at);

CREATE TABLE IF NOT EXISTS vehicles (
  id               TEXT PRIMARY KEY,
  owner_id         TEXT NOT NULL,
  name             TEXT NOT NULL,
  make             TEXT,
  model            TEXT,
  registration     TEXT,
  year             INTEGER,
  current_mileage  INTEGER,
  notes            TEXT,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_vehicles_owner ON vehicles(owner_id);

CREATE TABLE IF NOT EXISTS maintenance_records (
  id                 TEXT PRIMARY KEY,
  vehicle_id         TEXT,
  practical_item_id  TEXT,
  title              TEXT NOT NULL,
  description        TEXT,
  cost_minor         INTEGER,
  currency           TEXT,
  performed_at       INTEGER NOT NULL,
  next_due_at        INTEGER,
  mileage            INTEGER,
  expense_id         TEXT,
  notes              TEXT,
  created_at         INTEGER NOT NULL,
  FOREIGN KEY(vehicle_id)        REFERENCES vehicles(id) ON DELETE SET NULL,
  FOREIGN KEY(practical_item_id) REFERENCES practical_items(id) ON DELETE SET NULL,
  FOREIGN KEY(expense_id)        REFERENCES expenses(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance_records(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_next    ON maintenance_records(next_due_at);

CREATE TABLE IF NOT EXISTS shopping_lists (
  id           TEXT PRIMARY KEY,
  owner_id     TEXT NOT NULL,
  name         TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'OPEN',  -- OPEN | COMPLETED | ARCHIVED
  created_at   INTEGER NOT NULL,
  completed_at INTEGER,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_shopping_lists_owner ON shopping_lists(owner_id);

CREATE TABLE IF NOT EXISTS shopping_items (
  id                    TEXT PRIMARY KEY,
  shopping_list_id      TEXT NOT NULL,
  name                  TEXT NOT NULL,
  quantity              TEXT,
  estimated_price_minor INTEGER,
  actual_price_minor    INTEGER,
  currency              TEXT,
  category              TEXT,
  purchased             INTEGER NOT NULL DEFAULT 0,
  purchased_at          INTEGER,
  expense_id            TEXT,
  FOREIGN KEY(shopping_list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE,
  FOREIGN KEY(expense_id)       REFERENCES expenses(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_shopping_items_list ON shopping_items(shopping_list_id);

-- ---------------------------------------------------------------------------
-- 15. ACTIVITY EVENT LOG (immutable)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS activity_events (
  id           TEXT PRIMARY KEY,
  owner_id     TEXT NOT NULL,
  event_type   TEXT NOT NULL,
  entity_type  TEXT NOT NULL,
  entity_id    TEXT NOT NULL,
  occurred_at  INTEGER NOT NULL,
  recorded_at  INTEGER NOT NULL,
  source       TEXT NOT NULL,
  external_id  TEXT,
  metadata     TEXT,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(source, external_id)
);

CREATE INDEX IF NOT EXISTS idx_activity_owner_time ON activity_events(owner_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_activity_entity     ON activity_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_type       ON activity_events(event_type);
CREATE INDEX IF NOT EXISTS idx_activity_source     ON activity_events(source);
CREATE INDEX IF NOT EXISTS idx_activity_external   ON activity_events(source, external_id);

-- ---------------------------------------------------------------------------
-- 16. DERIVED VIEWS
-- ---------------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_open_tasks AS
SELECT *
FROM tasks
WHERE status NOT IN ('COMPLETED', 'CANCELLED')
  AND archived_at IS NULL;

CREATE VIEW IF NOT EXISTS v_open_habit_occurrences AS
SELECT *
FROM habit_occurrences
WHERE status = 'EXPECTED';

CREATE VIEW IF NOT EXISTS v_open_bill_occurrences AS
SELECT *
FROM bill_occurrences
WHERE status IN ('UPCOMING', 'DUE', 'OVERDUE');

CREATE VIEW IF NOT EXISTS v_pending_reminders AS
SELECT *
FROM reminders
WHERE status = 'PENDING';
