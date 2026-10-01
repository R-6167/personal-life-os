import Database from 'better-sqlite3';

export interface TodayTaskItem {
  id: string;
  title: string;
  status: string;
  dueAt?: number | null;
  projectId?: string | null;
  goalId?: string | null;
  priority?: number | null;
}

export interface TodayHabitItem {
  id: string;
  habitId: string;
  title: string;
  status: string;
  scheduledDate: number;
  scheduledTime?: number | null;
  actualDurationMinutes?: number | null;
}

export interface PersonalContext {
  currentTime: number;
  today: {
    tasks: TodayTaskItem[];
    habits: TodayHabitItem[];
    routines: unknown[];
    bills: unknown[];
  };
  overdueTasks: TodayTaskItem[];
  activeTasks: TodayTaskItem[];
  dueHabits: TodayHabitItem[];
  upcomingBills: unknown[];
  recentActivity: Array<{ id: string; eventType: string; entityType: string; entityId: string; occurredAt: number }>;
}

export class TodayContextBuilder {
  constructor(private readonly db: Database.Database) {}

  build(now: number = Date.now()): PersonalContext {
    const todayStart = this.startOfDay(now);
    const todayEnd = this.endOfDay(now);

    const tasks = this.db.prepare(`
      SELECT id, title, status, due_at AS dueAt, project_id AS projectId, goal_id AS goalId, priority
      FROM tasks
      WHERE owner_id = ?
        AND status NOT IN ('COMPLETED', 'CANCELLED', 'ARCHIVED')
        AND due_at >= ? AND due_at <= ?
      ORDER BY due_at ASC
    `).all('local-owner', todayStart, todayEnd) as TodayTaskItem[];

    const habits = this.db.prepare(`
      SELECT ho.id, h.id AS habitId, h.title, ho.status, ho.scheduled_date AS scheduledDate, ho.scheduled_time AS scheduledTime, ho.actual_duration_minutes AS actualDurationMinutes
      FROM habit_occurrences ho
      JOIN habits h ON h.id = ho.habit_id
      WHERE h.owner_id = ?
        AND ho.scheduled_date >= ? AND ho.scheduled_date <= ?
        AND ho.status IN ('EXPECTED', 'PARTIAL', 'MISSED')
      ORDER BY ho.scheduled_date ASC, ho.scheduled_time ASC
    `).all('local-owner', todayStart, todayEnd) as TodayHabitItem[];

    const overdueTasks = this.db.prepare(`
      SELECT id, title, status, due_at AS dueAt, project_id AS projectId, goal_id AS goalId, priority
      FROM tasks
      WHERE owner_id = ?
        AND status NOT IN ('COMPLETED', 'CANCELLED', 'ARCHIVED')
        AND due_at < ?
      ORDER BY due_at ASC
    `).all('local-owner', now) as TodayTaskItem[];

    const activeTasks = this.db.prepare(`
      SELECT id, title, status, due_at AS dueAt, project_id AS projectId, goal_id AS goalId, priority
      FROM tasks
      WHERE owner_id = ?
        AND status IN ('INBOX', 'PLANNED', 'IN_PROGRESS', 'WAITING')
      ORDER BY due_at ASC, priority DESC
    `).all('local-owner') as TodayTaskItem[];

    const dueHabits = this.db.prepare(`
      SELECT ho.id, h.id AS habitId, h.title, ho.status, ho.scheduled_date AS scheduledDate, ho.scheduled_time AS scheduledTime, ho.actual_duration_minutes AS actualDurationMinutes
      FROM habit_occurrences ho
      JOIN habits h ON h.id = ho.habit_id
      WHERE h.owner_id = ?
        AND ho.scheduled_date <= ?
        AND ho.status IN ('EXPECTED', 'PARTIAL', 'MISSED')
      ORDER BY ho.scheduled_date ASC
    `).all('local-owner', todayEnd) as TodayHabitItem[];

    const recentActivity = this.db.prepare(`
      SELECT id, event_type AS eventType, entity_type AS entityType, entity_id AS entityId, occurred_at AS occurredAt
      FROM activity_events
      WHERE owner_id = ?
      ORDER BY occurred_at DESC
      LIMIT 20
    `).all('local-owner') as Array<{ id: string; eventType: string; entityType: string; entityId: string; occurredAt: number }>;

    return {
      currentTime: now,
      today: {
        tasks,
        habits,
        routines: [],
        bills: [],
      },
      overdueTasks,
      activeTasks,
      dueHabits,
      upcomingBills: [],
      recentActivity,
    };
  }

  private startOfDay(timestamp: number): number {
    const d = new Date(timestamp);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  private endOfDay(timestamp: number): number {
    const d = new Date(timestamp);
    d.setHours(23, 59, 59, 999);
    return d.getTime();
  }
}

export function createTodayContextBuilder(db: Database.Database): TodayContextBuilder {
  return new TodayContextBuilder(db);
}
