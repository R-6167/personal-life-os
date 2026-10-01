import type { EventRecorder } from '../core/event-recorder.js';
import type { Goal, Project } from '../types.js';
import type { ProjectRepository } from '../repositories/project-repository.js';

export class ProjectService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createProject(input: Omit<Project, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Project {
    const now = Date.now();
    const project: Project = {
      ...input,
      id: input.id ?? crypto.randomUUID(),
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
    private readonly financeRepository: import('../repositories/finance-repository.js').FinanceRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createExpense(input: Omit<import('../types.js').Expense, 'id' | 'created_at' | 'updated_at'> & { id?: string }): import('../types.js').Expense {
    const now = Date.now();
    const expense: import('../types.js').Expense = {
      ...input,
      id: input.id ?? crypto.randomUUID(),
      created_at: now,
      updated_at: now,
      amount: input.amount,
      currency: input.currency ?? 'KES',
      description: input.description,
    };

    const saved = this.financeRepository.createExpense(expense);
    this.eventRecorder.record({
      ownerId: expense.owner_id,
      eventType: 'EXPENSE_RECORDED',
      entityType: 'EXPENSE',
      entityId: expense.id,
      occurredAt: now,
      source: 'FinanceService.createExpense',
      metadata: { amount: expense.amount, currency: expense.currency },
    });

    return saved;
  }
}
