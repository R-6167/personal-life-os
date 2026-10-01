import { randomUUID } from 'node:crypto';

import type { EventRecorder } from '../core/event-recorder.js';
import { assertNonNegative } from '../core/validation.js';
import type { Expense, FinancialAccount, Income, Project } from '../types.js';
import type { ProjectRepository } from '../repositories/project-repository.js';
import type { FinancialAccountRepository, FinanceRepository } from '../repositories/finance-repository.js';

export class ProjectService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createProject(input: Omit<Project, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Project {
    if (!input.title.trim()) throw new Error('Project title is required');
    assertNonNegative(input.priority ?? 0, 'priority');

    const now = Date.now();
    const project: Project = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
      status: input.status ?? 'PLANNED',
      priority: input.priority ?? 0,
      progress_mode: input.progress_mode ?? 'CALCULATED',
    };

    const saved = this.projectRepository.create(project);
    this.eventRecorder.record({
      ownerId: project.owner_id,
      eventType: 'PROJECT_CREATED',
      entityType: 'PROJECT',
      entityId: project.id,
      occurredAt: now,
      source: 'ProjectService.createProject',
      metadata: { title: project.title },
    });

    return saved;
  }

  startProject(projectId: string): Project | null {
    const updated = this.projectRepository.update(projectId, { status: 'ACTIVE' });
    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'PROJECT_STARTED',
      entityType: 'PROJECT',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'ProjectService.startProject',
    });

    return updated;
  }

  completeProject(projectId: string): Project | null {
    const updated = this.projectRepository.update(projectId, {
      status: 'COMPLETED',
      completed_at: Date.now(),
    });

    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'ProjectService.completeProject',
    });

    return updated;
  }
}

export class FinanceService {
  constructor(
    private readonly financeRepository: FinanceRepository,
    private readonly accountRepository: FinancialAccountRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createAccount(input: Omit<FinancialAccount, 'id' | 'created_at' | 'updated_at'> & { id?: string }): FinancialAccount {
    const now = Date.now();
    const account: FinancialAccount = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
      current_balance: input.current_balance ?? 0,
      is_tracked: input.is_tracked ?? 1,
    };

    return this.accountRepository.create(account);
  }

  recordExpense(input: Omit<Expense, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Expense {
    if (input.amount <= 0) throw new Error('Expense amount must be greater than zero');

    const now = Date.now();
    const expense: Expense = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
    };

    const saved = this.financeRepository.createExpense(expense);
    this.eventRecorder.record({
      ownerId: expense.owner_id,
      eventType: 'EXPENSE_RECORDED',
      entityType: 'EXPENSE',
      entityId: expense.id,
      occurredAt: expense.occurred_at,
      source: 'FinanceService.recordExpense',
      metadata: { amount: expense.amount, currency: expense.currency },
    });

    return saved;
  }

  recordIncome(input: Omit<Income, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Income {
    if (input.amount <= 0) throw new Error('Income amount must be greater than zero');

    const now = Date.now();
    const income: Income = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
    };

    const saved = this.financeRepository.createIncome(income);
    this.eventRecorder.record({
      ownerId: income.owner_id,
      eventType: 'INCOME_RECORDED',
      entityType: 'INCOME',
      entityId: income.id,
      occurredAt: income.occurred_at,
      source: 'FinanceService.recordIncome',
      metadata: { amount: income.amount, currency: income.currency },
    });

    return saved;
  }
}
