import type { Db } from './database';
import { DEFAULT_OWNER_ID, uid } from './database';
import type {
  AccountItem,
  ActivityItem,
  BillOccurrenceItem,
  ExpenseItem,
  GoalItem,
  HabitOccurrenceItem,
  ProjectItem,
  TaskItem,
} from '../types/app-data';

type Row = Record<string, unknown>;

function mapTask(r: Row): TaskItem {
  return {
    id: String(r.id),
    title: String(r.title),
    description: r.description != null ? String(r.description) : undefined,
    status: r.status as TaskItem['status'],
    priority: Number(r.priority ?? 0),
    dueAt: r.due_at != null ? Number(r.due_at) : null,
    estimatedMinutes: r.estimated_minutes != null ? Number(r.estimated_minutes) : null,
    projectTitle: r.project_title != null ? String(r.project_title) : null,
    projectId: r.project_id != null ? String(r.project_id) : null,
    goalId: r.goal_id != null ? String(r.goal_id) : null,
  };
}

export async function loadTasks(db: Db): Promise<TaskItem[]> {
  const rows = await db.getAllAsync(
    `SELECT t.*, p.title AS project_title
     FROM tasks t
     LEFT JOIN projects p ON p.id = t.project_id
     WHERE t.owner_id = ? AND t.archived_at IS NULL
     ORDER BY
       CASE t.status
         WHEN 'IN_PROGRESS' THEN 0
         WHEN 'PLANNED' THEN 1
         WHEN 'INBOX' THEN 2
         WHEN 'WAITING' THEN 3
         WHEN 'COMPLETED' THEN 4
         ELSE 5
       END,
       CASE WHEN t.due_at IS NULL THEN 1 ELSE 0 END, t.due_at ASC`,
    DEFAULT_OWNER_ID
  );
  return rows.map(mapTask);
}

export async function loadHabitOccurrences(db: Db): Promise<HabitOccurrenceItem[]> {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  const rows = await db.getAllAsync(
    `SELECT ho.*, h.title AS title
     FROM habit_occurrences ho
     JOIN habits h ON h.id = ho.habit_id
     WHERE ho.owner_id = ? AND ho.scheduled_date >= ?
     ORDER BY ho.scheduled_date ASC, h.title ASC`,
    DEFAULT_OWNER_ID,
    d.getTime()
  );
  return rows.map((r) => ({
    id: String(r.id),
    habitId: String(r.habit_id),
    title: String(r.title),
    status: r.status as HabitOccurrenceItem['status'],
    scheduledDate: Number(r.scheduled_date),
    targetMinutes: r.target_minutes != null ? Number(r.target_minutes) : null,
  }));
}

export async function loadBillOccurrences(db: Db): Promise<BillOccurrenceItem[]> {
  const rows = await db.getAllAsync(
    `SELECT bo.*, b.name AS name, b.provider AS provider, b.currency AS currency
     FROM bill_occurrences bo
     JOIN bills b ON b.id = bo.bill_id
     WHERE bo.owner_id = ?
     ORDER BY bo.due_at ASC`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    billId: String(r.bill_id),
    name: String(r.name),
    status: r.status as BillOccurrenceItem['status'],
    dueAt: Number(r.due_at),
    expectedAmountMinor: Number(r.expected_amount_minor),
    currency: String(r.currency ?? 'KES'),
    provider: r.provider != null ? String(r.provider) : null,
  }));
}

export async function loadAccounts(db: Db): Promise<AccountItem[]> {
  const rows = await db.getAllAsync(
    `SELECT * FROM financial_accounts WHERE owner_id = ? ORDER BY name`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    name: String(r.name),
    type: String(r.type),
    currency: String(r.currency ?? 'KES'),
    currentBalanceMinor: Number(r.current_balance_minor),
  }));
}

export async function loadExpenses(db: Db): Promise<ExpenseItem[]> {
  const rows = await db.getAllAsync(
    `SELECT * FROM expenses WHERE owner_id = ? ORDER BY occurred_at DESC LIMIT 30`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    description: String(r.description),
    amountMinor: Number(r.amount_minor),
    currency: String(r.currency ?? 'KES'),
    occurredAt: Number(r.occurred_at),
    merchant: r.merchant != null ? String(r.merchant) : null,
  }));
}

export async function loadActivity(db: Db): Promise<ActivityItem[]> {
  const rows = await db.getAllAsync(
    `SELECT * FROM activity_events WHERE owner_id = ? ORDER BY occurred_at DESC LIMIT 30`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => {
    let title = String(r.event_type);
    if (r.metadata) {
      try {
        const m = JSON.parse(String(r.metadata));
        if (m.title) title = m.title;
      } catch {
        /* ignore */
      }
    }
    return {
      id: String(r.id),
      eventType: String(r.event_type),
      entityType: String(r.entity_type),
      title,
      occurredAt: Number(r.occurred_at),
    };
  });
}

export async function loadGoals(db: Db): Promise<GoalItem[]> {
  const rows = await db.getAllAsync(
    `SELECT g.*,
       (SELECT COUNT(*) FROM projects p WHERE p.goal_id = g.id AND p.archived_at IS NULL) AS project_count,
       (SELECT COUNT(*) FROM tasks t WHERE t.goal_id = g.id AND t.status NOT IN ('COMPLETED','CANCELLED') AND t.archived_at IS NULL) AS open_tasks
     FROM goals g
     WHERE g.owner_id = ? AND g.archived_at IS NULL
     ORDER BY g.priority DESC, g.created_at DESC`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    title: String(r.title),
    description: r.description != null ? String(r.description) : null,
    status: String(r.status),
    priority: Number(r.priority ?? 0),
    targetDate: r.target_date != null ? Number(r.target_date) : null,
    projectCount: Number(r.project_count ?? 0),
    openTasks: Number(r.open_tasks ?? 0),
    manualProgress: r.manual_progress != null ? Number(r.manual_progress) : null,
  }));
}

export async function loadProjects(db: Db): Promise<ProjectItem[]> {
  const rows = await db.getAllAsync(
    `SELECT p.*, g.title AS goal_title,
       (SELECT COUNT(*) FROM tasks t WHERE t.project_id = p.id AND t.status NOT IN ('COMPLETED','CANCELLED') AND t.archived_at IS NULL) AS open_tasks,
       (SELECT COUNT(*) FROM tasks t WHERE t.project_id = p.id AND t.status = 'COMPLETED') AS completed_tasks
     FROM projects p
     LEFT JOIN goals g ON g.id = p.goal_id
     WHERE p.owner_id = ? AND p.archived_at IS NULL
     ORDER BY p.priority DESC, p.created_at DESC`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => {
    const open = Number(r.open_tasks ?? 0);
    const done = Number(r.completed_tasks ?? 0);
    const total = open + done;
    return {
      id: String(r.id),
      title: String(r.title),
      description: r.description != null ? String(r.description) : null,
      status: String(r.status),
      priority: Number(r.priority ?? 0),
      goalId: r.goal_id != null ? String(r.goal_id) : null,
      goalTitle: r.goal_title != null ? String(r.goal_title) : null,
      openTasks: open,
      completedTasks: done,
      progress: total === 0 ? 0 : Math.round((done / total) * 100),
    };
  });
}

async function recordEvent(
  db: Db,
  eventType: string,
  entityType: string,
  entityId: string,
  title: string
): Promise<void> {
  const now = Date.now();
  await db.runAsync(
    `INSERT INTO activity_events (id, owner_id, event_type, entity_type, entity_id, occurred_at, recorded_at, source, metadata)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'APP', ?)`,
    uid('act'),
    DEFAULT_OWNER_ID,
    eventType,
    entityType,
    entityId,
    now,
    now,
    JSON.stringify({ title })
  );
}

export async function completeTask(db: Db, id: string): Promise<void> {
  const now = Date.now();
  const task = await db.getFirstAsync<{ title: string }>(`SELECT title FROM tasks WHERE id = ?`, id);
  await db.runAsync(
    `UPDATE tasks SET status = 'COMPLETED', completed_at = ?, updated_at = ? WHERE id = ?`,
    now,
    now,
    id
  );
  if (task) await recordEvent(db, 'TASK_COMPLETED', 'TASK', id, task.title);
}

export async function startTask(db: Db, id: string): Promise<void> {
  const now = Date.now();
  const task = await db.getFirstAsync<{ title: string }>(`SELECT title FROM tasks WHERE id = ?`, id);
  await db.runAsync(`UPDATE tasks SET status = 'IN_PROGRESS', updated_at = ? WHERE id = ?`, now, id);
  if (task) await recordEvent(db, 'TASK_STARTED', 'TASK', id, task.title);
}

export async function createTask(
  db: Db,
  input: { title: string; description?: string; priority?: number; dueAt?: number | null; projectId?: string | null }
): Promise<string> {
  const now = Date.now();
  const id = uid('task');
  await db.runAsync(
    `INSERT INTO tasks (id, owner_id, project_id, title, description, status, priority, due_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'INBOX', ?, ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.projectId ?? null,
    input.title.trim(),
    input.description?.trim() || null,
    input.priority ?? 0,
    input.dueAt ?? null,
    now,
    now
  );
  await recordEvent(db, 'TASK_CREATED', 'TASK', id, input.title.trim());
  return id;
}

export async function completeHabitOccurrence(db: Db, id: string): Promise<void> {
  const now = Date.now();
  const row = await db.getFirstAsync<{ title: string }>(
    `SELECT h.title AS title FROM habit_occurrences ho JOIN habits h ON h.id = ho.habit_id WHERE ho.id = ?`,
    id
  );
  await db.runAsync(
    `UPDATE habit_occurrences SET status = 'COMPLETED', completed_at = ?, updated_at = ? WHERE id = ?`,
    now,
    now,
    id
  );
  if (row) await recordEvent(db, 'HABIT_COMPLETED', 'HABIT', id, row.title);
}

export async function skipHabitOccurrence(db: Db, id: string): Promise<void> {
  const now = Date.now();
  const row = await db.getFirstAsync<{ title: string }>(
    `SELECT h.title AS title FROM habit_occurrences ho JOIN habits h ON h.id = ho.habit_id WHERE ho.id = ?`,
    id
  );
  await db.runAsync(
    `UPDATE habit_occurrences SET status = 'SKIPPED', updated_at = ? WHERE id = ?`,
    now,
    id
  );
  if (row) await recordEvent(db, 'HABIT_SKIPPED', 'HABIT', id, row.title);
}

export async function createHabit(
  db: Db,
  input: { title: string; targetMinutes?: number }
): Promise<string> {
  const now = Date.now();
  const habitId = uid('habit');
  const title = input.title.trim();
  await db.runAsync(
    `INSERT INTO habits (id, owner_id, title, status, target_minutes, frequency, created_at, updated_at)
     VALUES (?, ?, ?, 'ACTIVE', ?, 'DAILY', ?, ?)`,
    habitId,
    DEFAULT_OWNER_ID,
    title,
    input.targetMinutes ?? null,
    now,
    now
  );
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  await db.runAsync(
    `INSERT INTO habit_occurrences (id, habit_id, owner_id, scheduled_date, status, target_minutes, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'EXPECTED', ?, ?, ?)`,
    uid('ho'),
    habitId,
    DEFAULT_OWNER_ID,
    d.getTime(),
    input.targetMinutes ?? null,
    now,
    now
  );
  await recordEvent(db, 'HABIT_CREATED', 'HABIT', habitId, title);
  return habitId;
}

export async function payBillOccurrence(db: Db, occurrenceId: string): Promise<void> {
  const now = Date.now();
  const occ = await db.getFirstAsync<{
    bill_id: string;
    expected_amount_minor: number;
    status: string;
    name: string;
    currency: string;
    provider: string | null;
  }>(
    `SELECT bo.*, b.name AS name, b.currency AS currency, b.provider AS provider
     FROM bill_occurrences bo JOIN bills b ON b.id = bo.bill_id WHERE bo.id = ?`,
    occurrenceId
  );
  if (!occ || occ.status === 'PAID') return;

  await db.runAsync(
    `UPDATE bill_occurrences SET status = 'PAID', paid_at = ?, actual_amount_minor = ?, updated_at = ? WHERE id = ?`,
    now,
    occ.expected_amount_minor,
    now,
    occurrenceId
  );

  const account = await db.getFirstAsync<{ id: string }>(
    `SELECT id FROM financial_accounts WHERE owner_id = ? AND type = 'MOBILE_MONEY' LIMIT 1`,
    DEFAULT_OWNER_ID
  );
  if (account) {
    await db.runAsync(
      `UPDATE financial_accounts SET current_balance_minor = current_balance_minor - ?, updated_at = ? WHERE id = ?`,
      occ.expected_amount_minor,
      now,
      account.id
    );
  }

  await db.runAsync(
    `INSERT INTO expenses (id, owner_id, account_id, description, amount_minor, currency, merchant, occurred_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    uid('exp'),
    DEFAULT_OWNER_ID,
    account?.id ?? null,
    `Payment: ${occ.name}`,
    occ.expected_amount_minor,
    occ.currency,
    occ.provider,
    now,
    now
  );

  await recordEvent(db, 'BILL_PAID', 'BILL', occurrenceId, occ.name);
}

export async function createGoal(
  db: Db,
  input: { title: string; description?: string; priority?: number; targetDate?: number | null }
): Promise<string> {
  const now = Date.now();
  const id = uid('goal');
  await db.runAsync(
    `INSERT INTO goals (id, owner_id, title, description, status, priority, target_date, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.title.trim(),
    input.description?.trim() || null,
    input.priority ?? 0,
    input.targetDate ?? null,
    now,
    now
  );
  await recordEvent(db, 'GOAL_CREATED', 'GOAL', id, input.title.trim());
  return id;
}

export async function createProject(
  db: Db,
  input: { title: string; description?: string; goalId?: string | null; priority?: number }
): Promise<string> {
  const now = Date.now();
  const id = uid('proj');
  await db.runAsync(
    `INSERT INTO projects (id, owner_id, goal_id, title, description, status, priority, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.goalId ?? null,
    input.title.trim(),
    input.description?.trim() || null,
    input.priority ?? 0,
    now,
    now
  );
  await recordEvent(db, 'PROJECT_CREATED', 'PROJECT', id, input.title.trim());
  return id;
}
