import type { PersonalContext, HabitOccurrence, Project, Task } from '../types.js';

import type { GoalRepository } from '../repositories/task-repository.js';
import type { HabitRepository } from '../repositories/habit-repository.js';
import type { TaskRepository } from '../repositories/task-repository.js';

export class ContextBuilder {
  constructor(
    private readonly taskRepository: TaskRepository,
    private readonly goalRepository: GoalRepository,
    private readonly habitRepository: HabitRepository
  ) {}

  build(ownerId: string): PersonalContext {
    const now = Date.now();
    const activeTasks = this.taskRepository.listActiveByOwner(ownerId);
    const overdueTasks = this.taskRepository.listOverdue(ownerId, now);
    const activeProjects: Project[] = [];
    const recentActivity: unknown[] = [];
    const habitsDue: HabitOccurrence[] = [];

    return {
      currentTime: now,
      today: new Date(now).setHours(0, 0, 0, 0),
      upcomingEvents: [],
      activeTasks,
      overdueTasks,
      activeProjects,
      upcomingMilestones: [],
      habitsDue,
      routinesDue: [],
      billsDue: [],
      subscriptionsRenewing: [],
      debtsDue: [],
      practicalDeadlines: [],
      recentActivity,
      availableTime: 120,
    };
  }
}
