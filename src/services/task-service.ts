import { randomUUID } from 'node:crypto';

import type { EventRecorder } from '../core/event-recorder.js';
import type { Goal, Habit, Task } from '../types.js';
import type { GoalRepository } from '../repositories/task-repository.js';
import type { HabitRepository } from '../repositories/habit-repository.js';
import type { TaskRepository } from '../repositories/task-repository.js';

export class TaskService {
  constructor(
    private readonly taskRepository: TaskRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createTask(input: Omit<Task, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Task {
    const now = Date.now();
    const task: Task = {
      ...input,
      id: input.id ?? randomUUID(),
      created_at: now,
      updated_at: now,
      status: input.status ?? 'INBOX',
      priority: input.priority ?? 0,
    };

    const saved = this.taskRepository.create(task);
    this.eventRecorder.record({
      ownerId: task.owner_id,
      eventType: 'TASK_CREATED',
      entityType: 'TASK',
      entityId: task.id,
      occurredAt: now,
      source: 'TaskService.createTask',
      metadata: { title: task.title, priority: task.priority },
    });

    return saved;
  }

  updateTask(taskId: string, updates: Partial<Task>): Task | null {
    const updated = this.taskRepository.update(taskId, updates);
    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'TASK_UPDATED',
      entityType: 'TASK',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'TaskService.updateTask',
      metadata: { changes: Object.keys(updates) },
    });

    return updated;
  }

  completeTask(taskId: string): Task | null {
    const updated = this.taskRepository.completeTask(taskId);
    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'TASK_COMPLETED',
      entityType: 'TASK',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'TaskService.completeTask',
    });

    return updated;
  }

  reopenTask(taskId: string): Task | null {
    const updated = this.taskRepository.reopenTask(taskId);
    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'TASK_REOPENED',
      entityType: 'TASK',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'TaskService.reopenTask',
    });

    return updated;
  }
}

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
    const existing = this.goalRepository.findById(goalId);
    if (!existing) return null;

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

  completeHabit(habitId: string): Habit | null {
    const updated = this.habitRepository.update(habitId, {
      status: 'COMPLETED',
      archived_at: Date.now(),
    });

    if (!updated) return null;

    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'HABIT_COMPLETED',
      entityType: 'HABIT',
      entityId: updated.id,
      occurredAt: Date.now(),
      source: 'HabitService.completeHabit',
    });

    return updated;
  }
}
