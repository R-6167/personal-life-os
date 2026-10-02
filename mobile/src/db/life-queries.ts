import type { Db } from './database';
import { DEFAULT_OWNER_ID, uid } from './database';

async function recordEvent(
  db: Db,
  eventType: string,
  entityType: string,
  entityId: string,
  title?: string
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
    title ? JSON.stringify({ title }) : null
  );
}

export async function loadNotes(db: Db) {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM notes WHERE owner_id = ? AND archived_at IS NULL
     ORDER BY pinned DESC, updated_at DESC LIMIT 100`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    title: r.title != null ? String(r.title) : null,
    body: String(r.body),
    projectId: r.project_id != null ? String(r.project_id) : null,
    goalId: r.goal_id != null ? String(r.goal_id) : null,
    pinned: Number(r.pinned) === 1,
    createdAt: Number(r.created_at),
    updatedAt: Number(r.updated_at),
  }));
}

export async function createNote(
  db: Db,
  input: { title?: string; body: string; projectId?: string | null; pinned?: boolean }
): Promise<string> {
  const now = Date.now();
  const id = uid('note');
  await db.runAsync(
    `INSERT INTO notes (id, owner_id, title, body, project_id, pinned, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.title?.trim() || null,
    input.body.trim(),
    input.projectId ?? null,
    input.pinned ? 1 : 0,
    now,
    now
  );
  await recordEvent(db, 'NOTE_CREATED', 'NOTE', id, input.title || input.body.slice(0, 40));
  return id;
}

export async function toggleNotePin(db: Db, id: string): Promise<void> {
  await db.runAsync(
    `UPDATE notes SET pinned = CASE WHEN pinned = 1 THEN 0 ELSE 1 END, updated_at = ? WHERE id = ?`,
    Date.now(),
    id
  );
}

export async function loadEvents(db: Db, fromTs?: number, toTs?: number) {
  const from = fromTs ?? Date.now() - 7 * 86400000;
  const to = toTs ?? Date.now() + 30 * 86400000;
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM events
     WHERE owner_id = ? AND starts_at >= ? AND starts_at <= ? AND status != 'CANCELLED'
     ORDER BY starts_at ASC LIMIT 100`,
    DEFAULT_OWNER_ID,
    from,
    to
  );
  return rows.map((r) => ({
    id: String(r.id),
    title: String(r.title),
    description: r.description != null ? String(r.description) : null,
    location: r.location != null ? String(r.location) : null,
    startsAt: Number(r.starts_at),
    endsAt: r.ends_at != null ? Number(r.ends_at) : null,
    allDay: Number(r.all_day) === 1,
    projectId: r.project_id != null ? String(r.project_id) : null,
    status: String(r.status),
  }));
}

export async function createEvent(
  db: Db,
  input: {
    title: string;
    description?: string;
    location?: string;
    startsAt: number;
    endsAt?: number | null;
    allDay?: boolean;
    projectId?: string | null;
  }
): Promise<string> {
  const now = Date.now();
  const id = uid('evt');
  await db.runAsync(
    `INSERT INTO events (id, owner_id, title, description, location, starts_at, ends_at, all_day, project_id, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'SCHEDULED', ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.title.trim(),
    input.description?.trim() || null,
    input.location?.trim() || null,
    input.startsAt,
    input.endsAt ?? null,
    input.allDay ? 1 : 0,
    input.projectId ?? null,
    now,
    now
  );
  await recordEvent(db, 'EVENT_CREATED', 'EVENT', id, input.title.trim());
  return id;
}

export async function loadReminders(db: Db) {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM reminders WHERE owner_id = ? AND status = 'PENDING'
     ORDER BY remind_at ASC LIMIT 50`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    title: String(r.title),
    body: r.body != null ? String(r.body) : null,
    remindAt: Number(r.remind_at),
    entityType: r.entity_type != null ? String(r.entity_type) : null,
    entityId: r.entity_id != null ? String(r.entity_id) : null,
    status: String(r.status),
  }));
}

export async function createReminder(
  db: Db,
  input: { title: string; body?: string; remindAt: number; entityType?: string; entityId?: string }
): Promise<string> {
  const now = Date.now();
  const id = uid('rem');
  await db.runAsync(
    `INSERT INTO reminders (id, owner_id, title, body, remind_at, entity_type, entity_id, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING', ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.title.trim(),
    input.body?.trim() || null,
    input.remindAt,
    input.entityType ?? null,
    input.entityId ?? null,
    now,
    now
  );
  await recordEvent(db, 'REMINDER_CREATED', 'REMINDER', id, input.title.trim());
  return id;
}

export async function completeReminder(db: Db, id: string): Promise<void> {
  const now = Date.now();
  await db.runAsync(
    `UPDATE reminders SET status = 'DONE', completed_at = ?, updated_at = ? WHERE id = ?`,
    now,
    now,
    id
  );
  await recordEvent(db, 'REMINDER_COMPLETED', 'REMINDER', id);
}

export async function loadInbox(db: Db) {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM inbox_items WHERE owner_id = ? AND status = 'OPEN'
     ORDER BY created_at DESC LIMIT 50`,
    DEFAULT_OWNER_ID
  );
  return rows.map((r) => ({
    id: String(r.id),
    rawText: String(r.raw_text),
    suggestedType: r.suggested_type != null ? String(r.suggested_type) : null,
    status: String(r.status),
    createdAt: Number(r.created_at),
  }));
}

export async function captureInbox(db: Db, rawText: string, suggestedType?: string): Promise<string> {
  const now = Date.now();
  const id = uid('inbox');
  const text = rawText.trim();
  let suggested = suggestedType ?? null;
  if (!suggested) {
    const lower = text.toLowerCase();
    if (lower.startsWith('note:') || lower.startsWith('idea:')) suggested = 'NOTE';
    else if (lower.startsWith('remind:') || lower.includes('remind me')) suggested = 'REMINDER';
    else if (lower.startsWith('habit:')) suggested = 'HABIT';
    else suggested = 'TASK';
  }
  await db.runAsync(
    `INSERT INTO inbox_items (id, owner_id, raw_text, suggested_type, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'OPEN', ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    text,
    suggested,
    now,
    now
  );
  await recordEvent(db, 'INBOX_CAPTURED', 'INBOX', id, text.slice(0, 60));
  return id;
}

export async function processInboxToTask(db: Db, inboxId: string): Promise<string> {
  const row = await db.getFirstAsync<{ raw_text: string }>(
    `SELECT raw_text FROM inbox_items WHERE id = ?`,
    inboxId
  );
  if (!row) throw new Error('Inbox item not found');
  const now = Date.now();
  const taskId = uid('task');
  await db.runAsync(
    `INSERT INTO tasks (id, owner_id, title, status, priority, created_at, updated_at)
     VALUES (?, ?, ?, 'INBOX', 0, ?, ?)`,
    taskId,
    DEFAULT_OWNER_ID,
    row.raw_text,
    now,
    now
  );
  await recordEvent(db, 'TASK_CREATED', 'TASK', taskId, row.raw_text);
  await db.runAsync(
    `UPDATE inbox_items SET status = 'PROCESSED', processed_entity_type = 'TASK',
     processed_entity_id = ?, updated_at = ? WHERE id = ?`,
    taskId,
    now,
    inboxId
  );
  return taskId;
}

export async function processInboxToNote(db: Db, inboxId: string): Promise<string> {
  const row = await db.getFirstAsync<{ raw_text: string }>(
    `SELECT raw_text FROM inbox_items WHERE id = ?`,
    inboxId
  );
  if (!row) throw new Error('Inbox item not found');
  const noteId = await createNote(db, { body: row.raw_text });
  const now = Date.now();
  await db.runAsync(
    `UPDATE inbox_items SET status = 'PROCESSED', processed_entity_type = 'NOTE',
     processed_entity_id = ?, updated_at = ? WHERE id = ?`,
    noteId,
    now,
    inboxId
  );
  return noteId;
}

export async function dismissInbox(db: Db, inboxId: string): Promise<void> {
  await db.runAsync(
    `UPDATE inbox_items SET status = 'DISMISSED', updated_at = ? WHERE id = ?`,
    Date.now(),
    inboxId
  );
}

export async function loadMilestones(db: Db, projectId?: string) {
  const sql = projectId
    ? `SELECT * FROM milestones WHERE owner_id = ? AND project_id = ? ORDER BY sort_order ASC, created_at ASC`
    : `SELECT m.*, p.title AS project_title FROM milestones m
       LEFT JOIN projects p ON p.id = m.project_id
       WHERE m.owner_id = ? ORDER BY m.project_id, m.sort_order ASC`;
  const rows = projectId
    ? await db.getAllAsync<Record<string, unknown>>(sql, DEFAULT_OWNER_ID, projectId)
    : await db.getAllAsync<Record<string, unknown>>(sql, DEFAULT_OWNER_ID);
  return rows.map((r) => ({
    id: String(r.id),
    projectId: String(r.project_id),
    projectTitle: r.project_title != null ? String(r.project_title) : null,
    title: String(r.title),
    description: r.description != null ? String(r.description) : null,
    status: String(r.status),
    targetDate: r.target_date != null ? Number(r.target_date) : null,
    completedAt: r.completed_at != null ? Number(r.completed_at) : null,
    sortOrder: Number(r.sort_order ?? 0),
  }));
}

export async function createMilestone(
  db: Db,
  input: { projectId: string; title: string; targetDate?: number | null }
): Promise<string> {
  const now = Date.now();
  const id = uid('ms');
  const max = await db.getFirstAsync<{ m: number }>(
    `SELECT COALESCE(MAX(sort_order), -1) AS m FROM milestones WHERE project_id = ?`,
    input.projectId
  );
  await db.runAsync(
    `INSERT INTO milestones (id, owner_id, project_id, title, status, sort_order, target_date, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'OPEN', ?, ?, ?, ?)`,
    id,
    DEFAULT_OWNER_ID,
    input.projectId,
    input.title.trim(),
    (max?.m ?? -1) + 1,
    input.targetDate ?? null,
    now,
    now
  );
  await recordEvent(db, 'MILESTONE_CREATED', 'MILESTONE', id, input.title.trim());
  return id;
}

export async function completeMilestone(db: Db, id: string): Promise<void> {
  const now = Date.now();
  await db.runAsync(
    `UPDATE milestones SET status = 'DONE', completed_at = ?, updated_at = ? WHERE id = ?`,
    now,
    now,
    id
  );
  await recordEvent(db, 'MILESTONE_COMPLETED', 'MILESTONE', id);
}
