export type TaskStatus =
  | 'INBOX'
  | 'PLANNED'
  | 'IN_PROGRESS'
  | 'WAITING'
  | 'COMPLETED'
  | 'CANCELLED';

export type HabitOccurrenceStatus =
  | 'EXPECTED'
  | 'COMPLETED'
  | 'MISSED'
  | 'SKIPPED'
  | 'PARTIAL';

export type BillOccurrenceStatus =
  | 'UPCOMING'
  | 'DUE'
  | 'OVERDUE'
  | 'PAID'
  | 'CANCELLED';

export interface TaskItem {
  id: string;
  title: string;
  description?: string;
  status: TaskStatus;
  priority: number;
  dueAt?: number | null;
  estimatedMinutes?: number | null;
  projectTitle?: string | null;
  projectId?: string | null;
  goalId?: string | null;
}

export interface HabitOccurrenceItem {
  id: string;
  habitId: string;
  title: string;
  status: HabitOccurrenceStatus;
  scheduledDate: number;
  targetMinutes?: number | null;
}

export interface BillOccurrenceItem {
  id: string;
  billId: string;
  name: string;
  status: BillOccurrenceStatus;
  dueAt: number;
  expectedAmountMinor: number;
  currency: string;
  provider?: string | null;
}

export interface AccountItem {
  id: string;
  name: string;
  type: string;
  currency: string;
  currentBalanceMinor: number;
}

export interface ExpenseItem {
  id: string;
  description: string;
  amountMinor: number;
  currency: string;
  occurredAt: number;
  merchant?: string | null;
}

export interface ActivityItem {
  id: string;
  eventType: string;
  entityType: string;
  title: string;
  occurredAt: number;
}

export interface GoalItem {
  id: string;
  title: string;
  description?: string | null;
  status: string;
  priority: number;
  targetDate?: number | null;
  projectCount: number;
  openTasks: number;
  manualProgress?: number | null;
}

export interface ProjectItem {
  id: string;
  title: string;
  description?: string | null;
  status: string;
  priority: number;
  goalId?: string | null;
  goalTitle?: string | null;
  openTasks: number;
  completedTasks: number;
  progress: number;
}

export interface NoteItem {
  id: string;
  title: string | null;
  body: string;
  projectId: string | null;
  goalId: string | null;
  pinned: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface EventItem {
  id: string;
  title: string;
  description: string | null;
  location: string | null;
  startsAt: number;
  endsAt: number | null;
  allDay: boolean;
  projectId: string | null;
  status: string;
}

export interface ReminderItem {
  id: string;
  title: string;
  body: string | null;
  remindAt: number;
  entityType: string | null;
  entityId: string | null;
  status: string;
}

export interface InboxItem {
  id: string;
  rawText: string;
  suggestedType: string | null;
  status: string;
  createdAt: number;
}

export interface MilestoneItem {
  id: string;
  projectId: string;
  projectTitle: string | null;
  title: string;
  description: string | null;
  status: string;
  targetDate: number | null;
  completedAt: number | null;
  sortOrder: number;
}

export interface RoutineStepItem {
  id: string;
  title: string;
  sortOrder: number;
  estimatedMinutes: number | null;
}

export interface RoutineItem {
  id: string;
  title: string;
  description: string | null;
  status: string;
  estimatedMinutes: number | null;
  frequency: string;
  steps: RoutineStepItem[];
}

export interface RoutineOccurrenceItem {
  id: string;
  routineId: string;
  title: string;
  scheduledDate: number;
  status: string;
}

export interface IncomeItem {
  id: string;
  description: string;
  amountMinor: number;
  currency: string;
  source: string | null;
  occurredAt: number;
}

export interface AppData {
  ready: boolean;
  error: string | null;
  tasks: TaskItem[];
  habitOccurrences: HabitOccurrenceItem[];
  billOccurrences: BillOccurrenceItem[];
  accounts: AccountItem[];
  recentExpenses: ExpenseItem[];
  recentActivity: ActivityItem[];
  goals: GoalItem[];
  projects: ProjectItem[];
  notes: NoteItem[];
  events: EventItem[];
  reminders: ReminderItem[];
  inbox: InboxItem[];
  milestones: MilestoneItem[];
  routines: RoutineItem[];
  routineOccurrences: RoutineOccurrenceItem[];
  income: IncomeItem[];
  refresh: () => Promise<void>;
  completeTask: (id: string) => Promise<void>;
  startTask: (id: string) => Promise<void>;
  createTask: (input: {
    title: string;
    description?: string;
    priority?: number;
    dueAt?: number | null;
    projectId?: string | null;
  }) => Promise<void>;
  completeHabit: (id: string) => Promise<void>;
  skipHabit: (id: string) => Promise<void>;
  createHabit: (input: {
    title: string;
    targetMinutes?: number;
    frequency?: 'DAILY' | 'WEEKLY' | 'MONTHLY';
    interval?: number;
    daysOfWeek?: number[] | null;
  }) => Promise<void>;
  payBill: (id: string) => Promise<void>;
  createGoal: (input: {
    title: string;
    description?: string;
    priority?: number;
    targetDate?: number | null;
  }) => Promise<void>;
  createProject: (input: {
    title: string;
    description?: string;
    goalId?: string | null;
    priority?: number;
  }) => Promise<void>;
  createNote: (input: {
    title?: string;
    body: string;
    projectId?: string | null;
    pinned?: boolean;
  }) => Promise<void>;
  toggleNotePin: (id: string) => Promise<void>;
  createEvent: (input: {
    title: string;
    description?: string;
    location?: string;
    startsAt: number;
    endsAt?: number | null;
    allDay?: boolean;
    projectId?: string | null;
  }) => Promise<void>;
  createReminder: (input: {
    title: string;
    body?: string;
    remindAt: number;
  }) => Promise<void>;
  completeReminder: (id: string) => Promise<void>;
  captureInbox: (rawText: string, suggestedType?: string) => Promise<void>;
  processInboxToTask: (id: string) => Promise<void>;
  processInboxToNote: (id: string) => Promise<void>;
  dismissInbox: (id: string) => Promise<void>;
  createMilestone: (input: {
    projectId: string;
    title: string;
    targetDate?: number | null;
  }) => Promise<void>;
  completeMilestone: (id: string) => Promise<void>;
  createRoutine: (input: {
    title: string;
    description?: string;
    estimatedMinutes?: number;
    frequency?: string;
    steps?: string[];
  }) => Promise<void>;
  completeRoutine: (id: string) => Promise<void>;
  createIncome: (input: {
    description: string;
    amountMinor: number;
    source?: string;
    accountId?: string | null;
  }) => Promise<void>;
}
