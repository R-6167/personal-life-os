import Database from 'better-sqlite3';
import { mapRow, mapRows } from './base-repository.js';
import {
  nowMs,
  newId,
  type ExpenseRecord,
  type FinancialAccountRecord,
  type IncomeRecord,
} from './repository-types.js';

export class FinanceRepository {
  constructor(private readonly db: Database.Database) {}

  // ── Accounts ──────────────────────────────────────────────────────────────

  createAccount(
    input: Omit<FinancialAccountRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & {
      id?: string;
    }
  ): FinancialAccountRecord {
    const now = nowMs();
    const item: FinancialAccountRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      name: input.name,
      type: input.type,
      currency: input.currency,
      currentBalanceMinor: input.currentBalanceMinor ?? 0,
      institution: input.institution ?? null,
      accountIdentifier: input.accountIdentifier ?? null,
      isTracked: input.isTracked ?? 1,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    };

    this.db
      .prepare(
        `INSERT INTO financial_accounts (
          id, owner_id, name, type, currency, current_balance_minor,
          institution, account_identifier, is_tracked, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        item.id,
        item.ownerId,
        item.name,
        item.type,
        item.currency,
        item.currentBalanceMinor,
        item.institution,
        item.accountIdentifier,
        item.isTracked,
        item.createdAt,
        item.updatedAt,
        item.archivedAt
      );

    return item;
  }

  findAccountById(id: string): FinancialAccountRecord | null {
    const row = this.db
      .prepare(`SELECT * FROM financial_accounts WHERE id = ?`)
      .get(id) as Record<string, unknown> | undefined;
    return mapRow<FinancialAccountRecord>(row);
  }

  listAccounts(ownerId: string): FinancialAccountRecord[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM financial_accounts WHERE owner_id = ? AND archived_at IS NULL ORDER BY name ASC`
      )
      .all(ownerId) as Record<string, unknown>[];
    return mapRows<FinancialAccountRecord>(rows);
  }

  /**
   * Cached balance adjustment. Transaction history remains authoritative;
   * recalculateBalance() can recompute from income − expenses when needed.
   */
  adjustAccountBalance(accountId: string, deltaMinor: number): void {
    this.db
      .prepare(
        `UPDATE financial_accounts
         SET current_balance_minor = COALESCE(current_balance_minor, 0) + ?,
             updated_at = ?
         WHERE id = ?`
      )
      .run(deltaMinor, nowMs(), accountId);
  }

  /**
   * Recompute cached balance from transaction history for one account.
   * balance = opening (0 if unknown) + income − expenses
   */
  recalculateBalance(accountId: string): number {
    const income = this.db
      .prepare(
        `SELECT COALESCE(SUM(amount_minor), 0) AS total FROM income WHERE account_id = ?`
      )
      .get(accountId) as { total: number };

    const expenses = this.db
      .prepare(
        `SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses WHERE account_id = ?`
      )
      .get(accountId) as { total: number };

    const balance = Number(income.total) - Number(expenses.total);

    this.db
      .prepare(
        `UPDATE financial_accounts SET current_balance_minor = ?, updated_at = ? WHERE id = ?`
      )
      .run(balance, nowMs(), accountId);

    return balance;
  }

  // ── Expenses ──────────────────────────────────────────────────────────────

  createExpense(
    input: Omit<ExpenseRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ): ExpenseRecord {
    const now = nowMs();
    const item: ExpenseRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      accountId: input.accountId ?? null,
      categoryId: input.categoryId ?? null,
      merchant: input.merchant ?? null,
      description: input.description,
      amountMinor: input.amountMinor,
      currency: input.currency,
      occurredAt: input.occurredAt,
      paymentMethod: input.paymentMethod ?? null,
      projectId: input.projectId ?? null,
      goalId: input.goalId ?? null,
      createdAt: now,
      updatedAt: now,
    };

    this.db
      .prepare(
        `INSERT INTO expenses (
          id, owner_id, account_id, category_id, merchant, description,
          amount_minor, currency, occurred_at, payment_method, project_id, goal_id,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        item.id,
        item.ownerId,
        item.accountId,
        item.categoryId,
        item.merchant,
        item.description,
        item.amountMinor,
        item.currency,
        item.occurredAt,
        item.paymentMethod,
        item.projectId,
        item.goalId,
        item.createdAt,
        item.updatedAt
      );

    return item;
  }

  // ── Income ────────────────────────────────────────────────────────────────

  createIncome(
    input: Omit<IncomeRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ): IncomeRecord {
    const now = nowMs();
    const item: IncomeRecord = {
      id: input.id ?? newId(),
      ownerId: input.ownerId,
      accountId: input.accountId ?? null,
      categoryId: input.categoryId ?? null,
      source: input.source,
      amountMinor: input.amountMinor,
      currency: input.currency,
      occurredAt: input.occurredAt,
      description: input.description ?? null,
      projectId: input.projectId ?? null,
      goalId: input.goalId ?? null,
      createdAt: now,
      updatedAt: now,
    };

    this.db
      .prepare(
        `INSERT INTO income (
          id, owner_id, account_id, category_id, source, amount_minor, currency,
          occurred_at, description, project_id, goal_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        item.id,
        item.ownerId,
        item.accountId,
        item.categoryId,
        item.source,
        item.amountMinor,
        item.currency,
        item.occurredAt,
        item.description,
        item.projectId,
        item.goalId,
        item.createdAt,
        item.updatedAt
      );

    return item;
  }
}
