/**
 * Recurrence type definitions for the Personal Life OS.
 * Defines how recurring entities (habits, bills, tasks, routines) repeat.
 */

/**
 * Frequency type for recurrence rules.
 */
export enum RecurrenceFrequency {
  DAILY = 'DAILY',
  WEEKLY = 'WEEKLY',
  BIWEEKLY = 'BIWEEKLY',
  MONTHLY = 'MONTHLY',
  QUARTERLY = 'QUARTERLY',
  YEARLY = 'YEARLY',
  CUSTOM = 'CUSTOM',
}

/**
 * Day of week for weekly recurrences.
 * 0 = Sunday, 1 = Monday, ..., 6 = Saturday
 */
export type DayOfWeek = 0 | 1 | 2 | 3 | 4 | 5 | 6;

/**
 * Recurrence rule for a recurring entity.
 * This represents the "definition" layer — not individual occurrences.
 */
export interface RecurrenceRule {
  frequency: RecurrenceFrequency;
  interval: number; // Every N days/weeks/months/years
  daysOfWeek?: DayOfWeek[]; // For WEEKLY/BIWEEKLY: which days [1, 3, 5] = Mon, Wed, Fri
  dayOfMonth?: number; // For MONTHLY: day of month (1-31)
  monthOfYear?: number; // For YEARLY: month (1-12)
  startDate: number; // Unix timestamp (ms)
  endDate?: number; // Unix timestamp (ms), optional
  timezone: string; // IANA timezone (e.g., 'Africa/Nairobi')
}

/**
 * Occurrence of a recurring entity.
 * This represents a specific expected instance.
 */
export interface OccurrenceInstance {
  id: string;
  scheduledDate: number; // Unix timestamp (ms) of the date
  scheduledTime?: number; // Unix timestamp (ms) of the specific time, if any
  status: 'EXPECTED' | 'COMPLETED' | 'SKIPPED' | 'MISSED' | 'PARTIAL';
}

/**
 * Habit recurrence details.
 * Extends RecurrenceRule with habit-specific fields.
 */
export interface HabitRecurrenceInfo extends RecurrenceRule {
  habitId: string;
  preferredTime?: number; // Preferred time of day (ms since midnight in timezone)
}

/**
 * Bill recurrence details.
 * Extends RecurrenceRule with bill-specific fields.
 */
export interface BillRecurrenceInfo extends RecurrenceRule {
  billId: string;
  expectedAmount?: number;
  currency: string;
}

/**
 * Task recurrence details.
 * Extends RecurrenceRule with task-specific fields.
 */
export interface TaskRecurrenceInfo extends RecurrenceRule {
  taskRecurrenceId: string;
  estimatedMinutes?: number;
}

/**
 * Routine recurrence details.
 * Extends RecurrenceRule with routine-specific fields.
 */
export interface RoutineRecurrenceInfo extends RecurrenceRule {
  routineId: string;
  preferredTime: number; // Preferred time of day for the routine
  estimatedMinutes?: number;
}

/**
 * Options for generating occurrences.
 */
export interface OccurrenceGenerationOptions {
  fromDate: number; // Start date (ms) for generation
  toDate: number; // End date (ms) for generation
  timezone: string; // IANA timezone for date calculations
  includeCompleted?: boolean; // Whether to include already-completed occurrences
}

/**
 * Result of generating occurrences.
 */
export interface GeneratedOccurrences {
  entityId: string;
  entityType: 'HABIT' | 'BILL' | 'TASK' | 'ROUTINE';
  occurrences: OccurrenceInstance[];
  generatedAt: number; // When this batch was generated
  fromDate: number;
  toDate: number;
}
