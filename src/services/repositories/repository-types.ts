import { randomUUID } from 'node:crypto';

export type EntityStatus =
  | 'ACTIVE'
  | 'INBOX'
  | 'PLANNED'
  | 'IN_PROGRESS'
  | 'WAITING'
  | 'COMPLETED'
  | 'PAUSED'
  | 'CANCELLED'
  | 'ARCHIVED';

export interface BaseRecord {
  id: string;
  ownerId: string;
  createdAt: number;
  updatedAt: number;
  archivedAt?: number | null;
}

export interface GoalRecord extends BaseRecord {
  title: string;
  description?: string | null;
  status: EntityStatus;
  priority: number;
  startDate?: number | null;
  targetDate?: number | null;
  completedAt?: number | null;
  progressMode?: string;
  manualProgress?: number | null;
}

export interface ProjectRecord extends BaseRecord {
  goalId?: string | null;
  title: string;
  description?: string | null;
  status: EntityStatus;
  priority: number;
  startDate?: number | null;
  targetDate?: number | null;
  completedAt?: number | null;
  progressMode?: string;
  manualProgress?: number | null;
}

export interface TaskRecord extends BaseRecord {
  projectId?: string | null;
  milestoneId?: string | null;
  goalId?: string | null;
  parentTaskId?: string | null;
  title: string;
  description?: string | null;
  status: EntityStatus;
  priority: number;
  scheduledStart?: number | null;
  scheduledEnd?: number | null;
  dueAt?: number | null;
  estimatedMinutes?: number | null;
  actualMinutes?: number | null;
  completedAt?: number | null;
  categoryId?: string | null;
}

export interface HabitRecord extends BaseRecord {
  goalId?: string | null;
  title: string;
  description?: string | null;
  status: EntityStatus;
  frequencyType?: string;
  targetCount: number;
  preferredTime?: number | null;
  durationMinutes?: number | null;
  startDate: number;
  endDate?: number | null;
  categoryId?: string | null;
}

export interface RoutineRecord extends BaseRecord {
  goalId?: string | null;
  name: string;
  description?: string | null;
  status: EntityStatus;
  estimatedMinutes?: number | null;
}

export interface BillRecord extends BaseRecord {
  name: string;
  provider?: string | null;
  description?: string | null;
  expectedAmountMinor?: number | null;
  currency: string;
  frequency?: string | null;
  nextDueAt?: number | null;
  status: string;
  categoryId?: string | null;
  defaultAccountId?: string | null;
}

export interface FinancialAccountRecord extends BaseRecord {
  name: string;
  type: string;
  currency: string;
  currentBalanceMinor?: number | null;
  institution?: string | null;
  accountIdentifier?: string | null;
  isTracked: number;
}

export interface ExpenseRecord {
  id: string;
  ownerId: string;
  accountId?: string | null;
  categoryId?: string | null;
  merchant?: string | null;
  description: string;
  amountMinor: number;
  currency: string;
  occurredAt: number;
  paymentMethod?: string | null;
  projectId?: string | null;
  goalId?: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface IncomeRecord {
  id: string;
  ownerId: string;
  accountId?: string | null;
  categoryId?: string | null;
  source: string;
  amountMinor: number;
  currency: string;
  occurredAt: number;
  description?: string | null;
  projectId?: string | null;
  goalId?: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface BillOccurrenceRecord {
  id: string;
  billId: string;
  periodStart?: number | null;
  periodEnd?: number | null;
  dueAt: number;
  expectedAmountMinor?: number | null;
  actualAmountMinor?: number | null;
  status: string;
  paidAt?: number | null;
  expenseId?: string | null;
  createdAt: number;
  updatedAt: number;
}

export function newId(): string {
  return randomUUID();
}

export function nowMs(): number {
  return Date.now();
}
