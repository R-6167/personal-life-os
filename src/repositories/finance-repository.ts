import type Database from 'better-sqlite3';
import type { Expense, FinancialAccount, Income } from '../types.js';
import { BaseRepository } from './base-repository.js';

export class FinancialAccountRepository extends BaseRepository<FinancialAccount> {
  protected readonly tableName = 'financial_accounts';
  protected toModel(row: Record<string, unknown>): FinancialAccount { return row as FinancialAccount; }

  create(account: FinancialAccount): FinancialAccount {
    this.db.prepare(`INSERT INTO financial_accounts
      (id, owner_id, name, type, currency, current_balance, institution, account_identifier, is_tracked, created_at, updated_at, archived_at)
      VALUES (@id, @owner_id, @name, @type, @currency, @current_balance, @institution, @account_identifier, @is_tracked, @created_at, @updated_at, @archived_at)`).run(account);
    return account;
  }
}

export class FinanceRepository extends BaseRepository<Expense> {
  protected readonly tableName = 'expenses';
  protected toModel(row: Record<string, unknown>): Expense { return row as Expense; }

  createExpense(expense: Expense): Expense {
    this.db.prepare(`INSERT INTO expenses
      (id, owner_id, account_id, category_id, merchant, description, amount, currency, occurred_at, payment_method, project_id, goal_id, created_at, updated_at)
      VALUES (@id, @owner_id, @account_id, @category_id, @merchant, @description, @amount, @currency, @occurred_at, @payment_method, @project_id, @goal_id, @created_at, @updated_at)`).run(expense);
    return expense;
  }

  createIncome(income: Income): Income {
    this.db.prepare(`INSERT INTO income
      (id, owner_id, account_id, category_id, source, amount, currency, occurred_at, description, project_id, goal_id, created_at, updated_at)
      VALUES (@id, @owner_id, @account_id, @category_id, @source, @amount, @currency, @occurred_at, @description, @project_id, @goal_id, @created_at, @updated_at)`).run(income);
    return income;
  }

  totalsByCurrency(ownerId: string): Array<{ currency: string; income: number; expenses: number }> {
    return this.db.prepare(`
      SELECT currency,
        COALESCE((SELECT SUM(amount) FROM income i WHERE i.owner_id = ? AND i.currency = e.currency), 0) AS income,
        COALESCE(SUM(e.amount), 0) AS expenses
      FROM expenses e WHERE e.owner_id = ? GROUP BY currency
    `).all(ownerId, ownerId) as Array<{ currency: string; income: number; expenses: number }>;
  }
}
