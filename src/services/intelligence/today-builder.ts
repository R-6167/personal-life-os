/**
 * Starter TodayBuilder for the Personal Life OS.
 *
 * This is a pragmatic "Today" view generator for the app. It takes the current
 * state of tasks, habits, routines, events, bills, and reminders and builds a
 * unified read model for the day.
 *
 * This is intentionally lightweight and does not yet connect to the SQLite layer.
 * It is designed to be used by a repository/service layer once those services exist.
 */

export type TodayItemKind =
  | 'TASK'
  | 'HABIT'
  | 'ROUTINE'
  | 'EVENT'
  | 'BILL'
  | 'REMINDER';

export interface TodayItem {
  id: string;
  kind: TodayItemKind;
  title: string;
  description?: string;
  status?: string;
  priority?: number;
  dueAt?: number;
  scheduledAt?: number;
  createdAt?: number;
  urgency?: 'OVERDUE' | 'TODAY' | 'UPCOMING';
}

export interface TodayView {
  date: number;
  tasks: TodayItem[];
  habits: TodayItem[];
  routines: TodayItem[];
  events: TodayItem[];
  bills: TodayItem[];
  reminders: TodayItem[];
  overdue: TodayItem[];
  all: TodayItem[];
  summary: {
    total: number;
    overdueCount: number;
    taskCount: number;
    habitCount: number;
    routineCount: number;
    billCount: number;
    reminderCount: number;
  };
}

export interface TodayBuilderInput {
  tasks?: Array<{
    id: string;
    title: string;
    description?: string;
    status?: string;
    priority?: number;
    dueAt?: number;
    scheduledStart?: number;
    createdAt?: number;
  }>;
  habits?: Array<{
    id: string;
    title: string;
    description?: string;
    status?: string;
    scheduledDate?: number;
    scheduledTime?: number;
    dueAt?: number;
    completedAt?: number;
    priority?: number;
  }>;
  routines?: Array<{
    id: string;
    title: string;
    description?: string;
    status?: string;
    scheduledAt?: number;
    dueAt?: number;
    priority?: number;
  }>;
  events?: Array<{
    id: string;
    title: string;
    description?: string;
    startAt?: number;
    endAt?: number;
    status?: string;
    dueAt?: number;
  }>;
  bills?: Array<{
    id: string;
    title: string;
    description?: string;
    status?: string;
    dueAt?: number;
    nextDueAt?: number;
    priority?: number;
  }>;
  reminders?: Array<{
    id: string;
    title: string;
    description?: string;
    status?: string;
    triggerAt?: number;
    dueAt?: number;
  }>;
}

export interface PersonalContext {
  timestamp: number;
  today: TodayView;
  activeTasks: TodayItem[];
  overdueTasks: TodayItem[];
  upcomingEvents: TodayItem[];
  dueHabits: TodayItem[];
  billsDueSoon: TodayItem[];
}

export class TodayBuilder {
  static build(input: TodayBuilderInput, now = Date.now()): TodayView {
    const todayStart = this.startOfDay(now);
    const todayEnd = this.endOfDay(now);

    const tasks = (input.tasks ?? [])
      .filter((task) => task.status !== 'COMPLETED' && task.status !== 'CANCELLED')
      .map((task) => this.toItem('TASK', task, task.dueAt ?? task.scheduledStart))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const habits = (input.habits ?? [])
      .map((habit) => this.toItem('HABIT', habit, habit.scheduledDate ?? habit.dueAt))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const routines = (input.routines ?? [])
      .map((routine) => this.toItem('ROUTINE', routine, routine.scheduledAt ?? routine.dueAt))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const events = (input.events ?? [])
      .map((event) => this.toItem('EVENT', event, event.startAt ?? event.endAt ?? event.dueAt))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const bills = (input.bills ?? [])
      .map((bill) => this.toItem('BILL', bill, bill.nextDueAt ?? bill.dueAt))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const reminders = (input.reminders ?? [])
      .map((reminder) => this.toItem('REMINDER', reminder, reminder.triggerAt ?? reminder.dueAt))
      .filter((item) => this.isTodayOrOverdue(item, todayStart, todayEnd));

    const all = [...tasks, ...habits, ...routines, ...events, ...bills, ...reminders];
    const overdue = all.filter((item) => item.urgency === 'OVERDUE');

    return {
      date: todayStart,
      tasks,
      habits,
      routines,
      events,
      bills,
      reminders,
      overdue,
      all,
      summary: {
        total: all.length,
        overdueCount: overdue.length,
        taskCount: tasks.length,
        habitCount: habits.length,
        routineCount: routines.length,
        billCount: bills.length,
        reminderCount: reminders.length,
      },
    };
  }

  static buildPersonalContext(input: TodayBuilderInput, now = Date.now()): PersonalContext {
    const today = TodayBuilder.build(input, now);

    const activeTasks = today.tasks.filter((item) => item.kind === 'TASK');
    const overdueTasks = today.overdue.filter((item) => item.kind === 'TASK');
    const upcomingEvents = today.events;
    const dueHabits = today.habits;
    const billsDueSoon = today.bills;

    return {
      timestamp: now,
      today,
      activeTasks,
      overdueTasks,
      upcomingEvents,
      dueHabits,
      billsDueSoon,
    };
  }

  private static toItem(
    kind: TodayItemKind,
    record: {
      id: string;
      title: string;
      description?: string;
      status?: string;
      priority?: number;
      dueAt?: number;
      scheduledAt?: number;
      scheduledDate?: number;
      createdAt?: number;
    },
    timestamp?: number
  ): TodayItem {
    const dueAt = timestamp ?? record.dueAt ?? record.scheduledAt ?? record.scheduledDate;

    return {
      id: record.id,
      kind,
      title: record.title,
      description: record.description,
      status: record.status,
      priority: record.priority,
      dueAt,
      scheduledAt: record.scheduledAt ?? record.scheduledDate,
      createdAt: record.createdAt,
      urgency: 'TODAY',
    };
  }

  private static isTodayOrOverdue(item: TodayItem, todayStart: number, todayEnd: number): boolean {
    if (!item.dueAt) {
      return false;
    }

    if (item.dueAt < todayStart && item.status !== 'COMPLETED' && item.status !== 'CANCELLED') {
      item.urgency = 'OVERDUE';
      return true;
    }

    if (item.dueAt >= todayStart && item.dueAt <= todayEnd) {
      item.urgency = 'TODAY';
      return true;
    }

    if (item.dueAt > todayEnd) {
      item.urgency = 'UPCOMING';
      return false;
    }

    return false;
  }

  private static startOfDay(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private static endOfDay(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(23, 59, 59, 999);
    return date.getTime();
  }
}

export const buildToday = TodayBuilder.build;
export const buildPersonalContext = TodayBuilder.buildPersonalContext;
