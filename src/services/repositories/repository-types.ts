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

export interface BillRecord extends BaseRecord {
  name: string;
  provider?: string | null;
  description?: string | null;
  expectedAmount?: number | null;
  currency: string;
  frequency?: string | null;
  nextDueAt?: number | null;
  status: string;
  categoryId?: string | null;
  defaultAccountId?: string | null;
}

export interface RepositoryQueryOptions<T> {
  limit?: number;
  offset?: number;
  where?: Partial<T>;
}

export interface RepositoryWriteResult<T> {
  item: T;
  success: true;
}

export function newId(): string {
  return randomUUID();
}

export function nowMs(): number {
  return Date.now();
}
