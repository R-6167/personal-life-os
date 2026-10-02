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
  createHabit: (input: { title: string; targetMinutes?: number }) => Promise<void>;
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
}
