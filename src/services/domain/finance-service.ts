import Database from 'better-sqlite3';
import { EventBus } from '../../intelligence/event-bus.js';
import { FinanceRepository } from '../repositories/finance-repository.js';
import type {
  ExpenseRecord,
  FinancialAccountRecord,
  IncomeRecord,
} from '../repositories/repository-types.js';
import { FinanceEventType, EntityType, EventSource } from '../../types/events.js';
import { nowMs } from '../repositories/repository-types.js';

export class FinanceService {
  private readonly finance: FinanceRepository;
  private readonly bus: EventBus;

  constructor(db: Database.Database, bus?: EventBus) {
    this.finance = new FinanceRepository(db);
    this.bus = bus ?? new EventBus(db);
  }

  createAccount(
    input: Omit<FinancialAccountRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & {
      id?: string;
    }
  ): FinancialAccountRecord {
    return this.finance.createAccount(input);
  }

  recordExpense(
    input: Omit<ExpenseRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ): ExpenseRecord {
    return this.bus.transaction((bus) => {
      const expense = this.finance.createExpense({
        ...input,
        occurredAt: input.occurredAt ?? nowMs(),
      });

      if (expense.accountId) {
        this.finance.adjustAccountBalance(expense.accountId, -expense.amountMinor);
      }

      bus.recordEvent({
        ownerId: expense.ownerId,
        eventType: FinanceEventType.EXPENSE_RECORDED,
        entityType: EntityType.EXPENSE,
        entityId: expense.id,
        source: EventSource.USER,
        occurredAt: expense.occurredAt,
        metadata: {
          amount: expense.amountMinor,
          currency: expense.currency,
          merchant: expense.merchant,
          paymentMethod: expense.paymentMethod,
          categoryId: expense.categoryId,
        },
      });

      return expense;
    });
  }

  recordIncome(
    input: Omit<IncomeRecord, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ): IncomeRecord {
    return this.bus.transaction((bus) => {
      const income = this.finance.createIncome({
        ...input,
        occurredAt: input.occurredAt ?? nowMs(),
      });

      if (income.accountId) {
        this.finance.adjustAccountBalance(income.accountId, income.amountMinor);
      }

      bus.recordEvent({
        ownerId: income.ownerId,
        eventType: FinanceEventType.INCOME_RECORDED,
        entityType: EntityType.INCOME,
        entityId: income.id,
        source: EventSource.USER,
        occurredAt: income.occurredAt,
        metadata: {
          amount: income.amountMinor,
          currency: income.currency,
          source: income.source,
        },
      });

      return income;
    });
  }

  getAccountBalance(accountId: string): number {
    const account = this.finance.findAccountById(accountId);
    return account?.currentBalanceMinor ?? 0;
  }

  recalculateBalance(accountId: string): number {
    return this.finance.recalculateBalance(accountId);
  }

  listAccounts(ownerId: string): FinancialAccountRecord[] {
    return this.finance.listAccounts(ownerId);
  }
}

export function createFinanceService(db: Database.Database, bus?: EventBus): FinanceService {
  return new FinanceService(db, bus);
}
