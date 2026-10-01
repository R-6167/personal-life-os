import { randomUUID } from 'node:crypto';

import type { EventRecorder } from '../core/event-recorder.js';
import type { Goal, Habit } from '../types.js';
import type { GoalRepository, HabitRepository } from '../repositories/task-repository.js';

export class GoalService {
  constructor(
    private readonly goalRepository: GoalRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createGoal(input: Omit<Goal, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Goal {
    const now = Date.now();
    const goal: Goal = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
      status: input.status ?? 'ACTIVE',
      priority: input.priority ?? 0,
      progress_mode: input.progress_mode ?? 'CALCULATED',
    };

    const saved = this.goalRepository.create(goal);
    this.eventRecorder.record({
      ownerId: goal.owner_id,
      eventType: 'GOAL_CREATED',
      entityType: 'GOAL',
      entityId: goal.id,
      occurredAt: now,
      source: 'GoalService.createGoal',
      metadata: { title: goal.title },
    });

    return saved;
  }

  completeGoal(goalId: string): Goal | null {
    const updated = this.goalRepository.update(goalId, {
      status: 'COMPLETED',
      completed_at: Date.now(),
    });

    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'GOAL_COMPLETED',
      entityType: 'GOAL',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'GoalService.completeGoal',
    });

    return updated;
  }
}

export class HabitService {
  constructor(
    private readonly habitRepository: HabitRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createHabit(input: Omit<Habit, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Habit {
    const now = Date.now();
    const habit: Habit = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
      status: input.status ?? 'ACTIVE',
      target_count: input.target_count ?? 1,
    };

    const saved = this.habitRepository.create(habit);
    this.eventRecorder.record({
      ownerId: habit.owner_id,
      eventType: 'HABIT_COMPLETED',
      entityType: 'HABIT',
      entityId: habit.id,
      occurredAt: now,
      source: 'HabitService.createHabit',
    });

    return saved;
  }
}
