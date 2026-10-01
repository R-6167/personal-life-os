import type { Expense } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class FinanceRepository extends BaseRepository<Expense> {
  protected readonly tableName = 'expenses';

  protected toModel(row: Record<string, unknown>): Expense {
    return row as Expense;
  }

  createExpense(expense: Expense): Expense {
    this.db.prepare(
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
    ).run(expense);

    return expense;
  }
}
