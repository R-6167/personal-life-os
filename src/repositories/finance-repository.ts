import type Database from 'better-sqlite3';

import type { Expense, Goal } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class FinanceRepository extends BaseRepository<Expense> {
  protected readonly tableName = 'expenses';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Expense {
    return row as Expense;
  }

  createExpense(expense: Expense): Expense {
    this.db
      .prepare(
        `
        INSERT INTO expenses (
          id, owner_id, account_id, category_id, merchant, description,
          amount, currency, occurred_at, payment_method, project_id,
          goal_id, created_at, updated_at
        ) VALUES (
          @id, @owner_id, @account_id, @category_id, @merchant, @description,
          @amount, @currency, @occurred_at, @payment_method, @project_id,
          @goal_id, @created_at, @updated_at
        )
        `
      )
      .run(expense);

    return expense;
  }

  listByOwner(ownerId: string): Expense[] {
    return super.listByOwner(ownerId);
  }
}

export class GoalRepository extends BaseRepository<Goal> {
  protected readonly tableName = 'goals';

  constructor(db: Database.Database) {
    super(db);
  }

  protected toModel(row: Record<string, unknown>): Goal {
    return row as Goal;
  }
}
