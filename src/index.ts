import { randomUUID } from 'node:crypto';

import { createDatabase } from './db/Database.js';
import { EventRecorder } from './core/event-recorder.js';
import { GoalRepository, TaskRepository } from './repositories/task-repository.js';
import { HabitRepository } from './repositories/habit-repository.js';
import { GoalService, HabitService, TaskService } from './services/index.js';
import { ContextBuilder } from './services/context-builder.js';

const db = createDatabase();

const existingUser = db
  .prepare('SELECT COUNT(*) as count FROM users WHERE id = ?')
  .get('demo-user') as { count: number };

if (existingUser.count === 0) {
  const now = Date.now();
  db.prepare(
    `
    INSERT INTO users (id, name, display_name, timezone, locale, currency, week_start_day, created_at, updated_at)
    VALUES (@id, @name, @display_name, @timezone, @locale, @currency, @week_start_day, @created_at, @updated_at)
    `
  ).run({
    id: 'demo-user',
    name: 'Demo User',
    display_name: 'You',
    timezone: 'UTC',
    locale: 'en',
    currency: 'KES',
    week_start_day: 1,
    created_at: now,
    updated_at: now,
  });
}

const eventRecorder = new EventRecorder(db);
const taskRepo = new TaskRepository(db);
const goalRepo = new GoalRepository(db);
const habitRepo = new HabitRepository(db);

const taskService = new TaskService(taskRepo, eventRecorder);
const goalService = new GoalService(goalRepo, eventRecorder);
const habitService = new HabitService(habitRepo, eventRecorder);

const goal = goalService.createGoal({
  owner_id: 'demo-user',
  title: 'Build a sustainable life system',
  description: 'Create the operating system for personal planning and life administration.',
  status: 'ACTIVE',
  priority: 10,
  progress_mode: 'CALCULATED',
  target_date: Date.now() + 1000 * 60 * 60 * 24 * 30,
});

const task = taskService.createTask({
  owner_id: 'demo-user',
  goal_id: goal.id,
  title: 'Set up app architecture and repositories',
  description: 'Establish the code backbone for the Personal Life OS domain model.',
  status: 'IN_PROGRESS',
  priority: 5,
  due_at: Date.now() + 1000 * 60 * 60 * 24 * 3,
});

const context = new ContextBuilder(taskRepo, goalRepo, habitRepo).build('demo-user');

console.log('Personal Life OS booted.');
console.log('Goal created:', goal.title);
console.log('Task created:', task.title);
console.log('Active tasks:', context.activeTasks.length);
console.log('Database location:', db.name);

db.close();
