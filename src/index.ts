import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

import { createDatabase } from './db/Database.js';
import { EventRecorder } from './core/event-recorder.js';
import { GoalRepository, TaskRepository } from './repositories/task-repository.js';
import { HabitRepository } from './repositories/habit-repository.js';
import { ProjectRepository } from './repositories/project-repository.js';
import { FinancialAccountRepository, FinanceRepository } from './repositories/finance-repository.js';
import { ContextBuilder } from './services/context-builder.js';
import { GoalService, HabitService, TaskService, ProjectService, FinanceService } from './services/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, 'public');

export function createApp() {
  const app = express();
  const db = createDatabase();

  const ensureUser = () => {
    const existingUser = db
      .prepare('SELECT COUNT(*) AS count FROM users WHERE id = ?')
      .get('demo-user') as { count: number };

    if (existingUser.count === 0) {
      const now = Date.now();
      db.prepare(`
        INSERT INTO users (
          id, name, display_name, timezone, locale, currency, week_start_day, created_at, updated_at
        ) VALUES (
          @id, @name, @display_name, @timezone, @locale, @currency, @week_start_day, @created_at, @updated_at
        )
      `).run({
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
  };

  const seedIfNeeded = () => {
    ensureUser();

    const taskCount = db.prepare('SELECT COUNT(*) AS count FROM tasks').get() as { count: number };
    if (taskCount.count > 0) return;

    const now = Date.now();
    const eventRecorder = new EventRecorder(db);
    const taskRepo = new TaskRepository(db);
    const goalRepo = new GoalRepository(db);
    const projectRepo = new ProjectRepository(db);
    const habitRepo = new HabitRepository(db);
    const financeRepo = new FinanceRepository(db);
    const accountRepo = new FinancialAccountRepository(db);

    const goalService = new GoalService(goalRepo, eventRecorder);
    const taskService = new TaskService(taskRepo, eventRecorder);
    const projectService = new ProjectService(projectRepo, eventRecorder);
    const financeService = new FinanceService(financeRepo, accountRepo, eventRecorder);
    const habitService = new HabitService(habitRepo, eventRecorder);

    const goal = goalService.createGoal({
      owner_id: 'demo-user',
      title: 'Build a sustainable life system',
      description: 'Create a calm, local-first planning system for life operations.',
      status: 'ACTIVE',
      priority: 10,
      progress_mode: 'CALCULATED',
      target_date: now + 1000 * 60 * 60 * 24 * 30,
    });

    projectService.createProject({
      owner_id: 'demo-user',
      goal_id: goal.id,
      title: 'Personal Life OS foundation',
      description: 'Complete the base model and workflows for planning, goals, tasks, and finance.',
      status: 'ACTIVE',
      priority: 8,
      progress_mode: 'CALCULATED',
      target_date: now + 1000 * 60 * 60 * 24 * 18,
    });

    taskService.createTask({
      owner_id: 'demo-user',
      goal_id: goal.id,
      title: 'Set up app architecture and repositories',
      description: 'Establish the code backbone for the Personal Life OS domain model.',
      status: 'IN_PROGRESS',
      priority: 5,
      due_at: now + 1000 * 60 * 60 * 24 * 3,
    });

    taskService.createTask({
      owner_id: 'demo-user',
      title: 'Review this week',
      description: 'Check the week’s commitments, errands, and priorities.',
      status: 'PLANNED',
      priority: 3,
      due_at: now + 1000 * 60 * 60 * 24 * 1,
    });

    habitService.createHabit({
      owner_id: 'demo-user',
      goal_id: goal.id,
      title: 'Exercise',
      description: 'Move daily to stay healthy and energized.',
      status: 'ACTIVE',
      target_count: 3,
      start_date: now,
      preferred_time: 18 * 60,
      duration_minutes: 30,
    });

    financeService.createAccount({
      owner_id: 'demo-user',
      name: 'Main Wallet',
      type: 'WALLET',
      currency: 'KES',
      current_balance: 15000,
      is_tracked: 1,
    });

    financeService.recordExpense({
      owner_id: 'demo-user',
      description: 'Groceries',
      amount: 1200,
      currency: 'KES',
      occurred_at: now,
      merchant: 'Fresh Market',
      payment_method: 'CASH',
    });

    financeService.recordIncome({
      owner_id: 'demo-user',
      source: 'Consulting',
      amount: 25000,
      currency: 'KES',
      occurred_at: now,
      description: 'Project payment',
    });
  };

  seedIfNeeded();

  const taskRepo = new TaskRepository(db);
  const goalRepo = new GoalRepository(db);
  const projectRepo = new ProjectRepository(db);
  const habitRepo = new HabitRepository(db);
  const financeRepo = new FinanceRepository(db);
  const accountRepo = new FinancialAccountRepository(db);
  const eventRecorder = new EventRecorder(db);
  const taskService = new TaskService(taskRepo, eventRecorder);
  const goalService = new GoalService(goalRepo, eventRecorder);
  const projectService = new ProjectService(projectRepo, eventRecorder);
  const financeService = new FinanceService(financeRepo, accountRepo, eventRecorder);
  const habitService = new HabitService(habitRepo, eventRecorder);
  const contextBuilder = new ContextBuilder(taskRepo, goalRepo, habitRepo);

  app.use(express.json());
  app.use(express.static(publicDir));

  app.get('/api/context', (_req, res) => {
    const context = contextBuilder.build('demo-user');
    res.json({
      user: {
        id: 'demo-user',
        name: 'Demo User',
        displayName: 'You',
        currency: 'KES',
      },
      context,
      summary: {
        openTasks: context.activeTasks.length,
        overdueTasks: context.overdueTasks.length,
        activeProjects: context.activeProjects.length,
        availableTime: context.availableTime,
      },
    });
  });

  app.get('/api/tasks', (_req, res) => {
    const tasks = taskRepo.listByOwner('demo-user');
    res.json(tasks);
  });

  app.get('/api/goals', (_req, res) => {
    const goals = goalRepo.listByOwner('demo-user');
    res.json(goals);
  });

  app.get('/api/projects', (_req, res) => {
    const projects = projectRepo.listByOwner('demo-user');
    res.json(projects);
  });

  app.get('/api/finance', (_req, res) => {
    const accounts = accountRepo.listByOwner('demo-user');
    const expenses = financeRepo.listByOwner('demo-user');
    const totals = financeRepo.totalsByCurrency('demo-user');
    res.json({ accounts, expenses, totals });
  });

  app.get('/api/habits', (_req, res) => {
    const habits = habitRepo.listByOwner('demo-user');
    res.json(habits);
  });

  app.post('/api/tasks', (req, res) => {
    const input = req.body ?? {};
    const created = taskService.createTask({
      owner_id: 'demo-user',
      title: String(input.title ?? 'New task'),
      description: input.description ?? '',
      status: input.status ?? 'INBOX',
      priority: Number(input.priority ?? 0),
      due_at: input.due_at ? Number(input.due_at) : undefined,
      goal_id: input.goal_id ?? null,
      project_id: input.project_id ?? null,
    });
    res.status(201).json(created);
  });

  app.post('/api/goals', (req, res) => {
    const input = req.body ?? {};
    const created = goalService.createGoal({
      owner_id: 'demo-user',
      title: String(input.title ?? 'New goal'),
      description: input.description ?? '',
      status: input.status ?? 'ACTIVE',
      priority: Number(input.priority ?? 0),
      progress_mode: input.progress_mode ?? 'CALCULATED',
      target_date: input.target_date ? Number(input.target_date) : undefined,
    });
    res.status(201).json(created);
  });

  app.post('/api/finance/expense', (req, res) => {
    const input = req.body ?? {};
    const created = financeService.recordExpense({
      owner_id: 'demo-user',
      description: String(input.description ?? 'Expense'),
      amount: Number(input.amount ?? 0),
      currency: String(input.currency ?? 'KES'),
      occurred_at: Number(input.occurred_at ?? Date.now()),
      merchant: input.merchant ?? '',
      payment_method: input.payment_method ?? 'CASH',
    });
    res.status(201).json(created);
  });

  app.get('/', (_req, res) => {
    res.sendFile(path.join(publicDir, 'index.html'));
  });

  return app;
}

export function startServer() {
  const app = createApp();
  const port = Number(process.env.PORT ?? 3000);
  app.listen(port, () => {
    console.log(`Personal Life OS is running at http://localhost:${port}`);
  });
}
