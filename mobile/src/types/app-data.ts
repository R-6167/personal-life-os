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

export interface AppData {
  tasks: TaskItem[];
  habitOccurrences: HabitOccurrenceItem[];
  billOccurrences: BillOccurrenceItem[];
  accounts: AccountItem[];
  recentExpenses: ExpenseItem[];
  recentActivity: ActivityItem[];
  completeTask: (id: string) => void;
  startTask: (id: string) => void;
  completeHabit: (id: string) => void;
  skipHabit: (id: string) => void;
  payBill: (id: string) => void;
}
