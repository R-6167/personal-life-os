export type Timestamp = number;

export type UserLocale = 'en' | 'fr' | 'sw' | 'es' | 'ar';
export type GoalStatus = 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED' | 'ARCHIVED';
export type ProjectStatus = 'PLANNED' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED' | 'ARCHIVED';
export type TaskStatus = 'INBOX' | 'PLANNED' | 'IN_PROGRESS' | 'WAITING' | 'COMPLETED' | 'CANCELLED';
export type HabitStatus = 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED' | 'ARCHIVED';
export type EventType =
  | 'TASK_CREATED'
  | 'TASK_UPDATED'
  | 'TASK_COMPLETED'
  | 'TASK_REOPENED'
  | 'TASK_CANCELLED'
  | 'GOAL_CREATED'
  | 'GOAL_PROGRESS_CHANGED'
  | 'GOAL_COMPLETED'
  | 'HABIT_CREATED'
  | 'HABIT_COMPLETED'
  | 'HABIT_SKIPPED'
  | 'HABIT_MISSED'
  | 'PROJECT_CREATED'
  | 'PROJECT_STARTED'
  | 'PROJECT_COMPLETED'
  | 'EXPENSE_RECORDED'
  | 'INCOME_RECORDED';

export interface User {
  id: string;
  name: string;
  display_name?: string | null;
  timezone: string;
  locale: UserLocale;
  currency: string;
  week_start_day: number;
  created_at: Timestamp;
  updated_at: Timestamp;
}

export interface Goal {
  id: string;
  owner_id: string;
  title: string;
  description?: string | null;
  status: GoalStatus;
  priority: number;
  start_date?: number | null;
  target_date?: number | null;
  completed_at?: number | null;
  progress_mode: 'CALCULATED' | 'MANUAL' | 'HYBRID';
  manual_progress?: number | null;
  created_at: Timestamp;
  updated_at: Timestamp;
  archived_at?: number | null;
}

export interface Project {
  id: string;
  owner_id: string;
  goal_id?: string | null;
  title: string;
  description?: string | null;
  status: ProjectStatus;
  priority: number;
  start_date?: number | null;
  target_date?: number | null;
  completed_at?: number | null;
  progress_mode: 'CALCULATED' | 'MANUAL' | 'HYBRID';
  manual_progress?: number | null;
  created_at: Timestamp;
  updated_at: Timestamp;
  archived_at?: number | null;
}

export interface Task {
  id: string;
  owner_id: string;
  project_id?: string | null;
  milestone_id?: string | null;
  goal_id?: string | null;
  parent_task_id?: string | null;
  title: string;
  description?: string | null;
  status: TaskStatus;
  priority: number;
  scheduled_start?: number | null;
  scheduled_end?: number | null;
  due_at?: number | null;
  estimated_minutes?: number | null;
  actual_minutes?: number | null;
  completed_at?: number | null;
  category_id?: string | null;
  created_at: Timestamp;
  updated_at: Timestamp;
  archived_at?: number | null;
}

export interface Habit {
  id: string;
  owner_id: string;
  goal_id?: string | null;
  title: string;
  description?: string | null;
  status: HabitStatus;
  target_count: number;
  preferred_time?: number | null;
  duration_minutes?: number | null;
  start_date: Timestamp;
  end_date?: number | null;
  category_id?: string | null;
  created_at: Timestamp;
  updated_at: Timestamp;
  archived_at?: number | null;
}

export interface HabitOccurrence {
  id: string;
  habit_id: string;
  scheduled_date: number;
  scheduled_time?: number | null;
  status: 'EXPECTED' | 'COMPLETED' | 'MISSED' | 'SKIPPED' | 'PARTIAL';
  completed_at?: number | null;
  skipped_at?: number | null;
  actual_duration_minutes?: number | null;
  reason?: string | null;
  notes?: string | null;
  created_at: Timestamp;
  updated_at: Timestamp;
}

export interface ActivityEvent {
  id: string;
  owner_id: string;
  event_type: EventType;
  entity_type: string;
  entity_id: string;
  occurred_at: Timestamp;
  recorded_at: Timestamp;
  source: string;
  external_id?: string | null;
  metadata?: string | null;
}

export interface FinancialAccount {
  id: string;
  owner_id: string;
  name: string;
  type: string;
  currency: string;
  current_balance?: number | null;
  institution?: string | null;
  account_identifier?: string | null;
  is_tracked: number;
  created_at: Timestamp;
  updated_at: Timestamp;
  archived_at?: number | null;
}

export interface Income {
  id: string;
  owner_id: string;
  account_id?: string | null;
  category_id?: string | null;
  source: string;
  amount: number;
  currency: string;
  occurred_at: Timestamp;
  description?: string | null;
  project_id?: string | null;
  goal_id?: string | null;
  created_at: Timestamp;
  updated_at: Timestamp;
}

export interface Expense {
  id: string;
  owner_id: string;
  account_id?: string | null;
  category_id?: string | null;
  merchant?: string | null;
  description: string;
  amount: number;
  currency: string;
  occurred_at: Timestamp;
  payment_method?: string | null;
  project_id?: string | null;
  goal_id?: string | null;
  created_at: Timestamp;
  updated_at: Timestamp;
}

export interface PersonalContext {
  currentTime: number;
  today: number;
  upcomingEvents: unknown[];
  activeTasks: Task[];
  overdueTasks: Task[];
  activeProjects: Project[];
  upcomingMilestones: unknown[];
  habitsDue: HabitOccurrence[];
  routinesDue: unknown[];
  billsDue: unknown[];
  subscriptionsRenewing: unknown[];
  debtsDue: unknown[];
  practicalDeadlines: unknown[];
  recentActivity: ActivityEvent[];
  availableTime: number;
}

export interface SortableEntity {
  id: string;
  created_at: number;
  updated_at: number;
}
