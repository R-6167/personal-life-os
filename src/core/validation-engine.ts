import type Database from 'better-sqlite3';
import type {
  Task,
  Goal,
  Habit,
  Project,
  HabitOccurrence,
  FinancialAccount,
  Expense,
  Income,
} from '../types.js';

export class ValidationError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly context?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Core domain validation rules for Personal Life OS.
 * Enforces invariants around task lifecycle, goal-project-task hierarchy,
 * habit scheduling, and financial consistency.
 */
export class ValidationEngine {
  constructor(private readonly db: Database.Database) {}

  /**
   * Validate task creation and state transitions.
   */
  validateTask(task: Partial<Task>, existingTask?: Task): void {
    // Title is required and non-empty
    if (!task.title || task.title.trim().length === 0) {
      throw new ValidationError('Task title is required', 'TASK_INVALID_TITLE', { task });
    }

    // Title length reasonable (max 255 chars)
    if (task.title.length > 255) {
      throw new ValidationError('Task title must be <= 255 characters', 'TASK_TITLE_TOO_LONG', {
        length: task.title.length,
      });
    }

    // Priority must be 0-10
    if (task.priority !== undefined) {
      this.assertInRange(task.priority, 0, 10, 'priority');
    }

    // Status must be a valid state
    const validTaskStatuses = ['INBOX', 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
    if (task.status && !validTaskStatuses.includes(task.status)) {
      throw new ValidationError(`Invalid task status: ${task.status}`, 'TASK_INVALID_STATUS', {
        status: task.status,
        valid: validTaskStatuses,
      });
    }

    // Due date must be in the future (if set)
    if (task.due_at !== undefined && task.due_at !== null) {
      if (task.due_at <= Date.now()) {
        throw new ValidationError(
          'Task due date must be in the future',
          'TASK_DUE_DATE_PAST',
          { due_at: task.due_at, now: Date.now() }
        );
      }
    }

    // If task has goal_id, goal must exist and belong to same owner
    if (task.goal_id) {
      this.validateEntityRelationship(task.owner_id, task.goal_id, 'goals', 'TASK_GOAL_NOT_FOUND');
    }

    // If task has project_id, project must exist and belong to same owner
    if (task.project_id) {
      this.validateEntityRelationship(
        task.owner_id,
        task.project_id,
        'projects',
        'TASK_PROJECT_NOT_FOUND'
      );
    }

    // Status transition rules (if updating existing task)
    if (existingTask) {
      this.validateTaskTransition(existingTask.status, task.status);
    }
  }

  /**
   * Validate goal creation and updates.
   */
  validateGoal(goal: Partial<Goal>, existingGoal?: Goal): void {
    // Title is required
    if (!goal.title || goal.title.trim().length === 0) {
      throw new ValidationError('Goal title is required', 'GOAL_INVALID_TITLE', { goal });
    }

    if (goal.title.length > 255) {
      throw new ValidationError('Goal title must be <= 255 characters', 'GOAL_TITLE_TOO_LONG', {
        length: goal.title.length,
      });
    }

    // Priority 0-10
    if (goal.priority !== undefined) {
      this.assertInRange(goal.priority, 0, 10, 'priority');
    }

    // Status must be valid
    const validStatuses = ['ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED'];
    if (goal.status && !validStatuses.includes(goal.status)) {
      throw new ValidationError(`Invalid goal status: ${goal.status}`, 'GOAL_INVALID_STATUS', {
        status: goal.status,
      });
    }

    // Progress mode must be valid
    const validModes = ['CALCULATED', 'MANUAL'];
    if (goal.progress_mode && !validModes.includes(goal.progress_mode)) {
      throw new ValidationError(
        `Invalid progress mode: ${goal.progress_mode}`,
        'GOAL_INVALID_PROGRESS_MODE',
        { progress_mode: goal.progress_mode }
      );
    }

    // Target date must be in future
    if (goal.target_date !== undefined && goal.target_date !== null) {
      if (goal.target_date <= Date.now()) {
        throw new ValidationError(
          'Goal target date must be in the future',
          'GOAL_TARGET_DATE_PAST',
          { target_date: goal.target_date }
        );
      }
    }
  }

  /**
   * Validate habit creation and recurrence rules.
   */
  validateHabit(habit: Partial<Habit>, existingHabit?: Habit): void {
    if (!habit.title || habit.title.trim().length === 0) {
      throw new ValidationError('Habit title is required', 'HABIT_INVALID_TITLE', { habit });
    }

    if (habit.title.length > 255) {
      throw new ValidationError('Habit title must be <= 255 characters', 'HABIT_TITLE_TOO_LONG', {
        length: habit.title.length,
      });
    }

    // Status validation
    const validStatuses = ['ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED'];
    if (habit.status && !validStatuses.includes(habit.status)) {
      throw new ValidationError(`Invalid habit status: ${habit.status}`, 'HABIT_INVALID_STATUS', {
        status: habit.status,
      });
    }

    // Target count must be positive if set
    if (habit.target_count !== undefined && habit.target_count !== null) {
      this.assertPositive(habit.target_count, 'target_count');
    }

    // Duration must be positive if set
    if (habit.duration_minutes !== undefined && habit.duration_minutes !== null) {
      this.assertPositive(habit.duration_minutes, 'duration_minutes');
    }

    // Preferred time must be valid (0-1440 minutes in a day)
    if (habit.preferred_time !== undefined && habit.preferred_time !== null) {
      this.assertInRange(habit.preferred_time, 0, 1440, 'preferred_time');
    }

    // Start date must be in past or today
    if (habit.start_date !== undefined && habit.start_date !== null) {
      if (habit.start_date > Date.now()) {
        throw new ValidationError(
          'Habit start date cannot be in the future',
          'HABIT_START_DATE_FUTURE',
          { start_date: habit.start_date }
        );
      }
    }

    // If goal_id is set, goal must exist
    if (habit.goal_id) {
      this.validateEntityRelationship(habit.owner_id, habit.goal_id, 'goals', 'HABIT_GOAL_NOT_FOUND');
    }
  }

  /**
   * Validate project creation and lifecycle.
   */
  validateProject(project: Partial<Project>, existingProject?: Project): void {
    if (!project.title || project.title.trim().length === 0) {
      throw new ValidationError('Project title is required', 'PROJECT_INVALID_TITLE', { project });
    }

    if (project.title.length > 255) {
      throw new ValidationError('Project title must be <= 255 characters', 'PROJECT_TITLE_TOO_LONG', {
        length: project.title.length,
      });
    }

    const validStatuses = ['PLANNED', 'ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED'];
    if (project.status && !validStatuses.includes(project.status)) {
      throw new ValidationError(`Invalid project status: ${project.status}`, 'PROJECT_INVALID_STATUS', {
        status: project.status,
      });
    }

    if (project.priority !== undefined) {
      this.assertInRange(project.priority, 0, 10, 'priority');
    }

    // Start and end date validation
    if (project.start_date && project.target_date) {
      if (project.target_date <= project.start_date) {
        throw new ValidationError(
          'Project target date must be after start date',
          'PROJECT_DATE_ORDER_INVALID',
          { start_date: project.start_date, target_date: project.target_date }
        );
      }
    }

    // If goal_id is set, validate it exists
    if (project.goal_id) {
      this.validateEntityRelationship(project.owner_id, project.goal_id, 'goals', 'PROJECT_GOAL_NOT_FOUND');
    }
  }

  /**
   * Validate financial account.
   */
  validateFinancialAccount(account: Partial<FinancialAccount>): void {
    if (!account.name || account.name.trim().length === 0) {
      throw new ValidationError(
        'Account name is required',
        'ACCOUNT_INVALID_NAME',
        { account }
      );
    }

    const validTypes = ['WALLET', 'CHECKING', 'SAVINGS', 'CREDIT_CARD', 'INVESTMENT'];
    if (account.type && !validTypes.includes(account.type)) {
      throw new ValidationError(`Invalid account type: ${account.type}`, 'ACCOUNT_INVALID_TYPE', {
        type: account.type,
      });
    }

    if (!account.currency || account.currency.length !== 3) {
      throw new ValidationError(
        'Currency must be a valid ISO 4217 code (3 chars)',
        'ACCOUNT_INVALID_CURRENCY',
        { currency: account.currency }
      );
    }
  }

  /**
   * Validate expense record.
   */
  validateExpense(expense: Partial<Expense>): void {
    if (!expense.description || expense.description.trim().length === 0) {
      throw new ValidationError(
        'Expense description is required',
        'EXPENSE_INVALID_DESCRIPTION',
        { expense }
      );
    }

    this.assertPositive(expense.amount ?? 0, 'amount');

    if (!expense.currency || expense.currency.length !== 3) {
      throw new ValidationError(
        'Currency must be a valid ISO 4217 code',
        'EXPENSE_INVALID_CURRENCY',
        { currency: expense.currency }
      );
    }

    // Occurred date must be today or in the past
    if (expense.occurred_at && expense.occurred_at > Date.now()) {
      throw new ValidationError(
        'Expense occurred_at cannot be in the future',
        'EXPENSE_DATE_FUTURE',
        { occurred_at: expense.occurred_at }
      );
    }
  }

  /**
   * Validate income record.
   */
  validateIncome(income: Partial<Income>): void {
    if (!income.source || income.source.trim().length === 0) {
      throw new ValidationError('Income source is required', 'INCOME_INVALID_SOURCE', { income });
    }

    this.assertPositive(income.amount ?? 0, 'amount');

    if (!income.currency || income.currency.length !== 3) {
      throw new ValidationError(
        'Currency must be a valid ISO 4217 code',
        'INCOME_INVALID_CURRENCY',
        { currency: income.currency }
      );
    }

    if (income.occurred_at && income.occurred_at > Date.now()) {
      throw new ValidationError(
        'Income occurred_at cannot be in the future',
        'INCOME_DATE_FUTURE',
        { occurred_at: income.occurred_at }
      );
    }
  }

  /**
   * Validate habit occurrence.
   */
  validateHabitOccurrence(occurrence: Partial<HabitOccurrence>): void {
    // Must reference an existing habit
    if (!occurrence.habit_id) {
      throw new ValidationError('Habit ID is required', 'OCCURRENCE_MISSING_HABIT_ID', {
        occurrence,
      });
    }

    const habit = this.db
      .prepare('SELECT id FROM habits WHERE id = ? AND owner_id = ?')
      .get(occurrence.habit_id, occurrence.owner_id);

    if (!habit) {
      throw new ValidationError('Referenced habit does not exist', 'OCCURRENCE_HABIT_NOT_FOUND', {
        habit_id: occurrence.habit_id,
      });
    }

    // Scheduled date must be today or in future
    if (occurrence.scheduled_for && occurrence.scheduled_for < this.todayStart()) {
      throw new ValidationError(
        'Habit occurrence scheduled_for must be today or in the future',
        'OCCURRENCE_SCHEDULED_PAST',
        { scheduled_for: occurrence.scheduled_for }
      );
    }

    // Status must be valid
    const validStatuses = ['PENDING', 'COMPLETED', 'SKIPPED'];
    if (occurrence.status && !validStatuses.includes(occurrence.status)) {
      throw new ValidationError(
        `Invalid occurrence status: ${occurrence.status}`,
        'OCCURRENCE_INVALID_STATUS',
        { status: occurrence.status }
      );
    }
  }

  /**
   * Validate task → goal → project hierarchy consistency.
   * Ensures a task's goal and project are related (same owner, consistent states).
   */
  validateTaskHierarchyConsistency(task: Task): void {
    if (!task.goal_id && !task.project_id) {
      // Task with no hierarchy is fine (e.g., inbox tasks)
      return;
    }

    if (task.goal_id && task.project_id) {
      // Validate that the project belongs to the same goal
      const project = this.db
        .prepare('SELECT goal_id FROM projects WHERE id = ? AND owner_id = ?')
        .get(task.project_id, task.owner_id) as { goal_id: string } | undefined;

      if (project && project.goal_id !== task.goal_id) {
        throw new ValidationError(
          'Task project must belong to the same goal',
          'TASK_HIERARCHY_MISMATCH',
          { goal_id: task.goal_id, project_id: task.project_id, project_goal_id: project?.goal_id }
        );
      }
    }

    // If task is completed, it should not block incomplete parent goal/project
    if (task.status === 'COMPLETED' && task.goal_id) {
      const goal = this.db
        .prepare('SELECT status FROM goals WHERE id = ? AND owner_id = ?')
        .get(task.goal_id, task.owner_id) as { status: string } | undefined;

      if (goal && goal.status === 'COMPLETED') {
        // Warn: completed task in completed goal is logical but not invalid
      }
    }
  }

  /**
   * Validate that all active tasks have realistic time allocations.
   * Helper for planning context builder.
   */
  validateTimeAllocation(
    ownerId: string,
    tasks: Task[],
    availableMinutesPerDay: number = 480
  ): { isValid: boolean; issues: string[] } {
    const issues: string[] = [];

    const activeTasks = tasks.filter(
      (t) => t.status === 'IN_PROGRESS' || (t.status === 'PLANNED' && t.due_at && t.due_at <= Date.now() + 86400000)
    );

    const totalEstimatedMinutes = activeTasks.reduce((sum, t) => {
      // Parse duration from description or metadata if available
      // For now, assume 60 min per task as default
      return sum + 60;
    }, 0);

    if (totalEstimatedMinutes > availableMinutesPerDay) {
      issues.push(
        `Active tasks (${totalEstimatedMinutes} min) exceed available time (${availableMinutesPerDay} min)`
      );
    }

    return {
      isValid: issues.length === 0,
      issues,
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helper methods
  // ─────────────────────────────────────────────────────────────────

  private assertPositive(value: number, fieldName: string): void {
    if (value <= 0) {
      throw new ValidationError(
        `${fieldName} must be positive (> 0)`,
        'VALIDATION_NOT_POSITIVE',
        { field: fieldName, value }
      );
    }
  }

  private assertNonNegative(value: number, fieldName: string): void {
    if (value < 0) {
      throw new ValidationError(
        `${fieldName} must be non-negative (>= 0)`,
        'VALIDATION_NOT_NON_NEGATIVE',
        { field: fieldName, value }
      );
    }
  }

  private assertInRange(value: number, min: number, max: number, fieldName: string): void {
    if (value < min || value > max) {
      throw new ValidationError(
        `${fieldName} must be between ${min} and ${max}`,
        'VALIDATION_OUT_OF_RANGE',
        { field: fieldName, value, min, max }
      );
    }
  }

  private validateEntityRelationship(
    ownerId: string,
    entityId: string,
    table: string,
    errorCode: string
  ): void {
    const entity = this.db
      .prepare(`SELECT id FROM ${table} WHERE id = ? AND owner_id = ?`)
      .get(entityId, ownerId);

    if (!entity) {
      throw new ValidationError(
        `Referenced entity does not exist: ${table}/${entityId}`,
        errorCode,
        { table, entityId, ownerId }
      );
    }
  }

  private validateTaskTransition(fromStatus: string, toStatus?: string): void {
    if (!toStatus) return;

    const validTransitions: Record<string, string[]> = {
      INBOX: ['PLANNED', 'CANCELLED'],
      PLANNED: ['IN_PROGRESS', 'CANCELLED'],
      IN_PROGRESS: ['COMPLETED', 'PLANNED', 'CANCELLED'],
      COMPLETED: [], // Cannot transition from COMPLETED
      CANCELLED: [], // Cannot transition from CANCELLED
    };

    const allowed = validTransitions[fromStatus] || [];

    if (!allowed.includes(toStatus)) {
      throw new ValidationError(
        `Invalid task status transition: ${fromStatus} → ${toStatus}`,
        'TASK_INVALID_TRANSITION',
        { from: fromStatus, to: toStatus, allowed }
      );
    }
  }

  private todayStart(): number {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  }
}
