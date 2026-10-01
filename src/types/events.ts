/**
 * Event types for the Personal Life OS activity event model.
 * These are standardized event types that feed into the ActivityEvent log.
 */

export enum TaskEventType {
  TASK_CREATED = 'TASK_CREATED',
  TASK_UPDATED = 'TASK_UPDATED',
  TASK_STARTED = 'TASK_STARTED',
  TASK_PAUSED = 'TASK_PAUSED',
  TASK_COMPLETED = 'TASK_COMPLETED',
  TASK_REOPENED = 'TASK_REOPENED',
  TASK_CANCELLED = 'TASK_CANCELLED',
  TASK_DEFERRED = 'TASK_DEFERRED',
}

export enum ProjectEventType {
  PROJECT_CREATED = 'PROJECT_CREATED',
  PROJECT_STARTED = 'PROJECT_STARTED',
  PROJECT_PAUSED = 'PROJECT_PAUSED',
  PROJECT_RESUMED = 'PROJECT_RESUMED',
  PROJECT_COMPLETED = 'PROJECT_COMPLETED',
  PROJECT_ARCHIVED = 'PROJECT_ARCHIVED',
  MILESTONE_COMPLETED = 'MILESTONE_COMPLETED',
}

export enum HabitEventType {
  HABIT_CREATED = 'HABIT_CREATED',
  HABIT_COMPLETED = 'HABIT_COMPLETED',
  HABIT_SKIPPED = 'HABIT_SKIPPED',
  HABIT_MISSED = 'HABIT_MISSED',
  HABIT_PARTIAL = 'HABIT_PARTIAL',
}

export enum RoutineEventType {
  ROUTINE_STARTED = 'ROUTINE_STARTED',
  ROUTINE_STEP_COMPLETED = 'ROUTINE_STEP_COMPLETED',
  ROUTINE_STEP_SKIPPED = 'ROUTINE_STEP_SKIPPED',
  ROUTINE_COMPLETED = 'ROUTINE_COMPLETED',
  ROUTINE_MISSED = 'ROUTINE_MISSED',
}

export enum CalendarEventType {
  EVENT_CREATED = 'EVENT_CREATED',
  EVENT_UPDATED = 'EVENT_UPDATED',
  EVENT_STARTED = 'EVENT_STARTED',
  EVENT_COMPLETED = 'EVENT_COMPLETED',
  EVENT_CANCELLED = 'EVENT_CANCELLED',
}

export enum FinanceEventType {
  INCOME_RECORDED = 'INCOME_RECORDED',
  EXPENSE_RECORDED = 'EXPENSE_RECORDED',
  BILL_CREATED = 'BILL_CREATED',
  BILL_DUE = 'BILL_DUE',
  BILL_PAID = 'BILL_PAID',
  BILL_OVERDUE = 'BILL_OVERDUE',
  SUBSCRIPTION_CREATED = 'SUBSCRIPTION_CREATED',
  SUBSCRIPTION_RENEWED = 'SUBSCRIPTION_RENEWED',
  SUBSCRIPTION_CANCELLED = 'SUBSCRIPTION_CANCELLED',
  DEBT_CREATED = 'DEBT_CREATED',
  DEBT_PAYMENT_RECORDED = 'DEBT_PAYMENT_RECORDED',
  SAVINGS_CONTRIBUTION_RECORDED = 'SAVINGS_CONTRIBUTION_RECORDED',
}

export enum PracticalEventType {
  DOCUMENT_CREATED = 'DOCUMENT_CREATED',
  DOCUMENT_EXPIRING = 'DOCUMENT_EXPIRING',
  DOCUMENT_EXPIRED = 'DOCUMENT_EXPIRED',
  MAINTENANCE_RECORDED = 'MAINTENANCE_RECORDED',
  RENEWAL_DUE = 'RENEWAL_DUE',
  APPOINTMENT_COMPLETED = 'APPOINTMENT_COMPLETED',
  SHOPPING_ITEM_PURCHASED = 'SHOPPING_ITEM_PURCHASED',
}

export enum GoalEventType {
  GOAL_CREATED = 'GOAL_CREATED',
  GOAL_PROGRESS_CHANGED = 'GOAL_PROGRESS_CHANGED',
  GOAL_COMPLETED = 'GOAL_COMPLETED',
  GOAL_PAUSED = 'GOAL_PAUSED',
}

// Union of all event types
export type EventType =
  | TaskEventType
  | ProjectEventType
  | HabitEventType
  | RoutineEventType
  | CalendarEventType
  | FinanceEventType
  | PracticalEventType
  | GoalEventType;

/**
 * Entity types that can trigger events
 */
export enum EntityType {
  TASK = 'TASK',
  PROJECT = 'PROJECT',
  MILESTONE = 'MILESTONE',
  GOAL = 'GOAL',
  HABIT = 'HABIT',
  HABIT_OCCURRENCE = 'HABIT_OCCURRENCE',
  ROUTINE = 'ROUTINE',
  ROUTINE_STEP = 'ROUTINE_STEP',
  ROUTINE_OCCURRENCE = 'ROUTINE_OCCURRENCE',
  CALENDAR_EVENT = 'CALENDAR_EVENT',
  INCOME = 'INCOME',
  EXPENSE = 'EXPENSE',
  BILL = 'BILL',
  BILL_OCCURRENCE = 'BILL_OCCURRENCE',
  SUBSCRIPTION = 'SUBSCRIPTION',
  DEBT = 'DEBT',
  DEBT_PAYMENT = 'DEBT_PAYMENT',
  SAVINGS_GOAL = 'SAVINGS_GOAL',
  SAVINGS_CONTRIBUTION = 'SAVINGS_CONTRIBUTION',
  DOCUMENT = 'DOCUMENT',
  VEHICLE = 'VEHICLE',
  MAINTENANCE_RECORD = 'MAINTENANCE_RECORD',
  PRACTICAL_ITEM = 'PRACTICAL_ITEM',
  NOTE = 'NOTE',
  PERSON = 'PERSON',
}

/**
 * Where the event originated from
 */
export enum EventSource {
  USER = 'USER',
  SYSTEM = 'SYSTEM',
  IMPORT = 'IMPORT',
  NOTIFICATION = 'NOTIFICATION',
  AUTOMATION = 'AUTOMATION',
  INTEGRATION = 'INTEGRATION',
  LOCAL_AI = 'LOCAL_AI',
}

/**
 * Base activity event structure
 */
export interface ActivityEvent {
  id: string;
  ownerId: string;
  eventType: EventType;
  entityType: EntityType;
  entityId: string;
  occurredAt: number; // Unix timestamp (ms) when the actual event happened
  recordedAt: number; // Unix timestamp (ms) when we recorded it
  source: EventSource;
  externalId?: string; // For deduplication from external systems
  metadata?: Record<string, unknown>; // Event-specific metadata (JSON)
}

/**
 * Metadata shapes for different event types
 */

export interface TaskCompletedMetadata {
  previousStatus: string;
  newStatus: string;
  actualMinutes?: number;
  estimatedMinutes?: number;
}

export interface ExpenseRecordedMetadata {
  amount: number;
  currency: string;
  merchant?: string;
  paymentMethod?: string;
  categoryId?: string;
}

export interface HabitCompletedMetadata {
  actualDurationMinutes?: number;
  scheduledDate: number;
  notes?: string;
}

export interface BillPaidMetadata {
  amount: number;
  currency: string;
  paymentMethod?: string;
  accountId?: string;
}

export interface GoalProgressChangedMetadata {
  previousProgress: number;
  newProgress: number;
  manualProgress?: boolean;
}

/**
 * Event creation parameters (without id, timestamps, or source)
 */
export interface CreateEventParams {
  ownerId: string;
  eventType: EventType;
  entityType: EntityType;
  entityId: string;
  occurredAt?: number; // Defaults to current time if not provided
  source?: EventSource; // Defaults to USER
  externalId?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Immutable event log entry with calculated timestamps
 */
export interface EventLogEntry extends ActivityEvent {
  recordedAt: number; // Always set by the recorder
  id: string; // Always generated by the recorder
}
