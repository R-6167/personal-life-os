import { randomUUID } from 'node:crypto';
import type { EventRecorder } from '../core/event-recorder.js';
import type { Expense, FinancialAccount, Income } from '../types.js';
import type { FinanceRepository, FinancialAccountRepository } from '../repositories/finance-repository.js';

export class FinanceService {
  constructor(
    private readonly financeRepository: FinanceRepository,
    private readonly accountRepository: FinancialAccountRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createAccount(input: Omit<FinancialAccount, 'id' | 'created_at' | 'updated_at'> & { id?: string }): FinancialAccount {
    const now = Date.now();
    const account: FinancialAccount = { ...input, id: input.id ?? randomUUID(), created_at: now, updated_at: now, current_balance: input.current_balance ?? 0, is_tracked: input.is_tracked ?? 1 };
    return this.accountRepository.create(account);
  }

  recordExpense(input: Omit<Expense, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Expense {
    if (input.amount <= 0) throw new Error('Expense amount must be greater than zero');
    const now = Date.now();
    const expense: Expense = { ...input, id: input.id ?? randomUUID(), created_at: now, updated_at: now };
    const saved = this.financeRepository.createExpense(expense);
    this.eventRecorder.record({ ownerId: expense.owner_id, eventType: 'EXPENSE_RECORDED', entityType: 'EXPENSE', entityId: expense.id, occurredAt: expense.occurred_at, source: 'FinanceService.recordExpense', metadata: { amount: expense.amount, currency: expense.currency } });
    return saved;
  }

  recordIncome(input: Omit<Income, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Income {
    if (input.amount <= 0) throw new Error('Income amount must be greater than zero');
    const now = Date.now();
    const income: Income = { ...input, id: input.id ?? randomUUID(), created_at: now, updated_at: now };
    const saved = this.financeRepository.createIncome(income);
    this.eventRecorder.record({ ownerId: income.owner_id, eventType: 'INCOME_RECORDED', entityType: 'INCOME', entityId: income.id, occurredAt: income.occurred_at, source: 'FinanceService.recordIncome', metadata: { amount: income.amount, currency: income.currency } });
    return saved;
  }
}
