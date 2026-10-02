import { createDatabase } from './db/index.js';
import { createEventBus } from './intelligence/event-bus.js';
import { createTaskService } from './services/domain/task-service.js';
import { createHabitService } from './services/domain/habit-service.js';
import { createBillService } from './services/domain/bill-service.js';
import { createFinanceService } from './services/domain/finance-service.js';
import { createTodayContextBuilder } from './services/intelligence/today-context-builder.js';
import { toMomentumContext } from './services/intelligence/momentum-context.js';
import { newId, nowMs } from './services/repositories/repository-types.js';
import { RecurrenceFrequency } from './services/recurrence/recurrence-types.js';

function ensureUser(db: ReturnType<typeof createDatabase>, ownerId: string) {
  const existing = db.prepare(`SELECT id FROM users WHERE id = ?`).get(ownerId);
  if (existing) return;

  const now = nowMs();
  db.prepare(
    `INSERT INTO users (id, name, display_name, timezone, locale, currency, week_start_day, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(ownerId, 'Local User', 'You', 'Africa/Nairobi', 'en', 'KES', 1, now, now);
}

function main() {
  const db = createDatabase('./data/personal-life-os.db');
  const ownerId = 'local-owner';
  ensureUser(db, ownerId);

  const bus = createEventBus(db);
  const tasks = createTaskService(db, bus);
  const habits = createHabitService(db, bus);
  const bills = createBillService(db, bus);
  const finance = createFinanceService(db, bus);
  const todayBuilder = createTodayContextBuilder(db);

  console.log('Personal Life OS — domain services demo\n');

  // 1. Account
  const account = finance.createAccount({
    ownerId,
    name: 'M-Pesa',
    type: 'MOBILE_MONEY',
    currency: 'KES',
    currentBalanceMinor: 50_000_00, // KSh 50,000.00 in minor units (cents)
    isTracked: 1,
  });
  console.log('Account:', account.name, 'balance_minor=', account.currentBalanceMinor);

  // 2. Task lifecycle
  const task = tasks.create({
    ownerId,
    title: 'Ship Personal Life OS domain layer',
    status: 'PLANNED',
    priority: 1,
    dueAt: nowMs() + 2 * 60 * 60 * 1000,
    estimatedMinutes: 90,
  });
  tasks.start(task.id);
  const completed = tasks.complete(task.id, 75);
  console.log('Task completed:', completed.title, '→', completed.status);

  // 3. Habit + occurrence
  const habit = habits.create({
    ownerId,
    title: 'Exercise',
    status: 'ACTIVE',
    targetCount: 1,
    startDate: nowMs(),
    frequencyType: 'WEEKLY',
  });

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const weekEnd = new Date(todayStart);
  weekEnd.setDate(weekEnd.getDate() + 7);

  const habitOccs = habits.generateOccurrences(
    habit.id,
    {
      frequency: RecurrenceFrequency.WEEKLY,
      interval: 1,
      daysOfWeek: [1, 3, 5], // Mon Wed Fri
      startDate: todayStart.getTime(),
      timezone: 'Africa/Nairobi',
    },
    {
      fromDate: todayStart.getTime(),
      toDate: weekEnd.getTime(),
      timezone: 'Africa/Nairobi',
    }
  );
  console.log('Habit occurrences generated:', habitOccs.length);

  if (habitOccs[0]) {
    const done = habits.completeOccurrence(habitOccs[0].id, {
      actualDurationMinutes: 30,
      notes: 'Morning run',
    });
    console.log('Habit occurrence completed:', done.status);
  }

  // 4. Bill + pay
  const bill = bills.create({
    ownerId,
    name: 'Electricity',
    provider: 'Kenya Power',
    currency: 'KES',
    frequency: 'MONTHLY',
    nextDueAt: nowMs() + 24 * 60 * 60 * 1000,
    expectedAmountMinor: 3_500_00,
    status: 'ACTIVE',
    defaultAccountId: account.id,
  });

  const billOccs = bills.generateOccurrences(
    bill.id,
    {
      frequency: RecurrenceFrequency.MONTHLY,
      interval: 1,
      dayOfMonth: new Date().getDate(),
      startDate: todayStart.getTime(),
      timezone: 'Africa/Nairobi',
    },
    {
      fromDate: todayStart.getTime(),
      toDate: weekEnd.getTime(),
      timezone: 'Africa/Nairobi',
    },
    3_500_00
  );
  console.log('Bill occurrences generated:', billOccs.length);

  if (billOccs[0]) {
    const paid = bills.payOccurrence(billOccs[0].id, {
      amountMinor: 3_500_00,
      currency: 'KES',
      accountId: account.id,
      paymentMethod: 'MOBILE_MONEY',
    });
    console.log(
      'Bill paid → expense',
      paid.expense.id,
      'occurrence',
      paid.occurrence.status
    );
  }

  // 5. Income
  finance.recordIncome({
    ownerId,
    accountId: account.id,
    source: 'Salary',
    amountMinor: 80_000_00,
    currency: 'KES',
    occurredAt: nowMs(),
  });

  const balance = finance.getAccountBalance(account.id);
  console.log('Account balance_minor after txns:', balance);

  // 6. Personal context + Momentum contract
  const context = todayBuilder.build(ownerId);
  const momentum = toMomentumContext(context);

  console.log('\n── Personal Context ──');
  console.log('Active tasks:', context.activeTasks.length);
  console.log('Due habits:', context.dueHabits.length);
  console.log('Upcoming bills:', context.upcomingBills.length);
  console.log('Recent activity events:', context.recentActivity.length);
  console.log(
    'Recent event types:',
    context.recentActivity.map((e) => e.eventType).join(', ')
  );

  console.log('\n── Momentum Context ──');
  console.log(JSON.stringify(momentum, null, 2));

  console.log('\nDemo complete.');
  db.close();
}

main();
