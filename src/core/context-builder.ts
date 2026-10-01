import type Database from 'better-sqlite3';
import type {
  Task,
  Goal,
  Habit,
  Project,
  HabitOccurrence,
  FinancialAccount,
} from '../types.js';
import { ValidationEngine } from './validation-engine.js';

/**
 * Represents a user's current context and focus for a given day.
 * Built from tasks, goals, habits, and financial data.
 */
export interface DailyContext {
  userId: string;
  date: Date;
  summary: string;

  // Today's high-level focus
  todaysTheme?: string;
  priorityRange: [number, number]; // [min, max] priority of active tasks
  estimatedMinutes: number;

  // Active entities
  activeTasks: Task[];
  activeTodayHabits: HabitOccurrence[];
  activeGoals: Goal[];
  activeProjects: Project[];

  // Financial snapshot
  accountSnapshots: Array<{
    account: FinancialAccount;
    balance: number;
    lastUpdated: number;
  }>;

  // Alerts and warnings
  warnings: Array<{
    severity: 'info' | 'warning' | 'critical';
    message: string;
    context?: Record<string, unknown>;
  }>;

  // Metadata
  lastBuilt: number;
  isStale: boolean;
}

/**
 * ContextBuilder constructs a daily context from database entities.
 * Uses ValidationEngine to ensure consistency and surface issues.
 * Focuses on today's tasks, habits, goals, and financial snapshots.
 */
export class ContextBuilder {
  private readonly validation: ValidationEngine;

  constructor(private readonly db: Database.Database) {
    this.validation = new ValidationEngine(db);
  }

  /**
   * Build a complete daily context for a user.
   */
  buildDailyContext(userId: string, forDate: Date = new Date()): DailyContext {
    const dayStart = this.getDayStart(forDate);
    const dayEnd = dayStart + 86400000; // 24 hours

    // Fetch today's tasks
    const todaysTasks = this.getTodaysTasks(userId, dayStart, dayEnd);

    // Fetch today's active habits and their occurrences
    const todaysHabits = this.getTodaysHabitOccurrences(userId, dayStart, dayEnd);

    // Fetch active goals and projects
    const activeGoals = this.getActiveGoals(userId);
    const activeProjects = this.getActiveProjects(userId);

    // Fetch financial snapshots
    const accountSnapshots = this.getFinancialSnapshots(userId);

    // Collect warnings
    const warnings = this.collectWarnings(userId, todaysTasks, todaysHabits, activeGoals);

    // Calculate priority range and estimated minutes
    const priorityRange = this.calculatePriorityRange(todaysTasks);
    const estimatedMinutes = this.estimateTotalMinutes(todaysTasks);

    // Generate daily theme
    const theme = this.generateDailyTheme(activeGoals, todaysTasks);

    // Build summary
    const summary = this.buildSummary(
      todaysTasks,
      todaysHabits,
      activeGoals,
      estimatedMinutes,
      warnings
    );

    return {
      userId,
      date: new Date(dayStart),
      summary,
      todaysTheme: theme,
      priorityRange,
      estimatedMinutes,
      activeTasks: todaysTasks,
      activeTodayHabits: todaysHabits,
      activeGoals,
      activeProjects,
      accountSnapshots,
      warnings,
      lastBuilt: Date.now(),
      isStale: false,
    };
  }

  /**
   * Get tasks scheduled for today, considering due dates and status.
   */
  private getTodaysTasks(userId: string, dayStart: number, dayEnd: number): Task[] {
    const query = `
      SELECT * FROM tasks
      WHERE owner_id = ?
        AND status IN ('PLANNED', 'IN_PROGRESS')
        AND (
          due_at IS NULL
          OR (due_at >= ? AND due_at < ?)
          OR status = 'IN_PROGRESS'
        )
      ORDER BY priority DESC, due_at ASC
      LIMIT 50
    `;

    const tasks = this.db.prepare(query).all(userId, dayStart, dayEnd) as Task[];

    // Validate each task for consistency
    tasks.forEach((task) => {
      try {
        this.validation.validateTaskHierarchyConsistency(task);
      } catch (err) {
        // Log but don't throw; we want to include the task even if hierarchy is inconsistent
        console.warn(`Task ${task.id} hierarchy issue:`, err);
      }
    });

    return tasks;
  }

  /**
   * Get habit occurrences scheduled for today.
   */
  private getTodaysHabitOccurrences(
    userId: string,
    dayStart: number,
    dayEnd: number
  ): HabitOccurrence[] {
    const query = `
      SELECT * FROM habit_occurrences
      WHERE owner_id = ?
        AND scheduled_for >= ?
        AND scheduled_for < ?
        AND status IN ('PENDING', 'COMPLETED')
      ORDER BY scheduled_for ASC
    `;

    return this.db.prepare(query).all(userId, dayStart, dayEnd) as HabitOccurrence[];
  }

  /**
   * Get all active goals for the user.
   */
  private getActiveGoals(userId: string): Goal[] {
    const query = `
      SELECT * FROM goals
      WHERE owner_id = ?
        AND status IN ('ACTIVE', 'PAUSED')
      ORDER BY priority DESC
      LIMIT 20
    `;

    return this.db.prepare(query).all(userId) as Goal[];
  }

  /**
   * Get all active projects for the user.
   */
  private getActiveProjects(userId: string): Project[] {
    const query = `
      SELECT * FROM projects
      WHERE owner_id = ?
        AND status IN ('PLANNED', 'ACTIVE')
      ORDER BY priority DESC
      LIMIT 20
    `;

    return this.db.prepare(query).all(userId) as Project[];
  }

  /**
   * Get financial account snapshots.
   * Returns current balance estimate for each account.
   */
  private getFinancialSnapshots(
    userId: string
  ): Array<{
    account: FinancialAccount;
    balance: number;
    lastUpdated: number;
  }> {
    const accounts = this.db
      .prepare('SELECT * FROM financial_accounts WHERE owner_id = ?')
      .all(userId) as FinancialAccount[];

    return accounts.map((account) => {
      // Calculate balance from expenses and income
      const expenseSum = this.db
        .prepare(
          `
        SELECT COALESCE(SUM(amount), 0) as total
        FROM expenses
        WHERE owner_id = ? AND account_id = ? AND currency = ?
      `
        )
        .get(userId, account.id, account.currency) as { total: number };

      const incomeSum = this.db
        .prepare(
          `
        SELECT COALESCE(SUM(amount), 0) as total
        FROM income
        WHERE owner_id = ? AND account_id = ? AND currency = ?
      `
        )
        .get(userId, account.id, account.currency) as { total: number };

      const balance = (account.initial_balance || 0) + incomeSum.total - expenseSum.total;

      return {
        account,
        balance,
        lastUpdated: Date.now(),
      };
    });
  }

  /**
   * Collect warnings and alerts for the daily context.
   */
  private collectWarnings(
    userId: string,
    tasks: Task[],
    habits: HabitOccurrence[],
    goals: Goal[]
  ): Array<{
    severity: 'info' | 'warning' | 'critical';
    message: string;
    context?: Record<string, unknown>;
  }> {
    const warnings: Array<{
      severity: 'info' | 'warning' | 'critical';
      message: string;
      context?: Record<string, unknown>;
    }> = [];

    // Check time allocation
    const timeCheck = this.validation.validateTimeAllocation(userId, tasks, 480); // 8 hours
    if (!timeCheck.isValid) {
      warnings.push({
        severity: 'warning',
        message: timeCheck.issues.join('; '),
        context: { tasks: tasks.length, estimatedMinutes: this.estimateTotalMinutes(tasks) },
      });
    }

    // Check for overdue tasks
    const overdueTasks = tasks.filter((t) => t.due_at && t.due_at < Date.now());
    if (overdueTasks.length > 0) {
      warnings.push({
        severity: 'critical',
        message: `${overdueTasks.length} task(s) are overdue`,
        context: { taskIds: overdueTasks.map((t) => t.id) },
      });
    }

    // Check for incomplete high-priority tasks
    const highPriorityIncomplete = tasks.filter(
      (t) => t.priority >= 8 && t.status !== 'COMPLETED'
    );
    if (highPriorityIncomplete.length > 2) {
      warnings.push({
        severity: 'info',
        message: `${highPriorityIncomplete.length} high-priority tasks in progress`,
        context: { taskIds: highPriorityIncomplete.map((t) => t.id) },
      });
    }

    // Check for incomplete habits
    const pendingHabits = habits.filter((h) => h.status === 'PENDING');
    if (pendingHabits.length > 5) {
      warnings.push({
        severity: 'info',
        message: `${pendingHabits.length} habits scheduled for today`,
        context: { habitCount: pendingHabits.length },
      });
    }

    // Check goal progress
    const stalledGoals = goals.filter((g) => {
      const lastUpdate = g.updated_at || g.created_at;
      return Date.now() - lastUpdate > 7 * 86400000; // 7 days
    });
    if (stalledGoals.length > 0) {
      warnings.push({
        severity: 'warning',
        message: `${stalledGoals.length} goal(s) haven't been updated in 7+ days`,
        context: { goalIds: stalledGoals.map((g) => g.id) },
      });
    }

    return warnings;
  }

  /**
   * Calculate priority range of tasks.
   */
  private calculatePriorityRange(tasks: Task[]): [number, number] {
    if (tasks.length === 0) return [0, 0];
    const priorities = tasks.map((t) => t.priority || 0);
    return [Math.min(...priorities), Math.max(...priorities)];
  }

  /**
   * Estimate total minutes for all tasks (simple heuristic).
   */
  private estimateTotalMinutes(tasks: Task[]): number {
    // Simple heuristic: 60 min per task (can be enhanced with task metadata)
    return Math.min(tasks.length * 60, 480); // Cap at 8 hours
  }

  /**
   * Generate a thematic focus for the day based on goals.
   */
  private generateDailyTheme(goals: Goal[], tasks: Task[]): string {
    if (goals.length === 0) return 'General focus';

    const topGoal = goals[0];
    if (topGoal.title.length > 40) {
      return topGoal.title.substring(0, 40) + '...';
    }
    return topGoal.title;
  }

  /**
   * Build a human-readable summary of the day.
   */
  private buildSummary(
    tasks: Task[],
    habits: HabitOccurrence[],
    goals: Goal[],
    estimatedMinutes: number,
    warnings: Array<{ severity: string; message: string }>
  ): string {
    const parts: string[] = [];

    if (tasks.length > 0) {
      parts.push(`${tasks.length} task${tasks.length !== 1 ? 's' : ''} today`);
    }

    if (habits.length > 0) {
      parts.push(`${habits.length} habit${habits.length !== 1 ? 's' : ''} to track`);
    }

    if (goals.length > 0) {
      parts.push(`${goals.length} active goal${goals.length !== 1 ? 's' : ''}`);
    }

    if (estimatedMinutes > 0) {
      parts.push(`~${estimatedMinutes} minutes planned`);
    }

    const critical = warnings.filter((w) => w.severity === 'critical');
    if (critical.length > 0) {
      parts.push(`⚠️ ${critical.length} alert${critical.length !== 1 ? 's' : ''}`);
    }

    return parts.join(' • ');
  }

  /**
   * Get the start of a day in milliseconds.
   */
  private getDayStart(date: Date): number {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }
}
