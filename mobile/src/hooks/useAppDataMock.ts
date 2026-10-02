import { useCallback, useMemo, useState } from 'react';
import type {
  AccountItem,
  ActivityItem,
  AppData,
  BillOccurrenceItem,
  ExpenseItem,
  HabitOccurrenceItem,
  TaskItem,
} from '../types/app-data';

function startOfToday(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function hoursFromNow(h: number): number {
  return Date.now() + h * 60 * 60 * 1000;
}

function daysFromNow(d: number): number {
  return Date.now() + d * 24 * 60 * 60 * 1000;
}

function uid(prefix: string): string {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}`;
}

const INITIAL_TASKS: TaskItem[] = [
  {
    id: 'task_1',
    title: 'Ship Personal Life OS domain layer',
    description: 'Wire transactional services and demo',
    status: 'IN_PROGRESS',
    priority: 2,
    dueAt: hoursFromNow(4),
    estimatedMinutes: 90,
    projectTitle: 'Personal Life OS',
  },
  {
    id: 'task_2',
    title: 'Review electricity bill',
    status: 'PLANNED',
    priority: 1,
    dueAt: hoursFromNow(8),
    estimatedMinutes: 15,
    projectTitle: 'Home',
  },
  {
    id: 'task_3',
    title: 'Call John about project kickoff',
    status: 'INBOX',
    priority: 0,
    dueAt: daysFromNow(1),
    estimatedMinutes: 20,
  },
  {
    id: 'task_4',
    title: 'Draft weekly review notes',
    status: 'WAITING',
    priority: 0,
    dueAt: daysFromNow(-1),
    estimatedMinutes: 30,
    projectTitle: 'Personal Life OS',
  },
];

const INITIAL_HABITS: HabitOccurrenceItem[] = [
  {
    id: 'ho_1',
    habitId: 'habit_exercise',
    title: 'Exercise',
    status: 'EXPECTED',
    scheduledDate: startOfToday(),
    targetMinutes: 30,
  },
  {
    id: 'ho_2',
    habitId: 'habit_read',
    title: 'Read 20 pages',
    status: 'EXPECTED',
    scheduledDate: startOfToday(),
    targetMinutes: 25,
  },
  {
    id: 'ho_3',
    habitId: 'habit_water',
    title: 'Drink water (morning)',
    status: 'COMPLETED',
    scheduledDate: startOfToday(),
    targetMinutes: 5,
  },
];

const INITIAL_BILLS: BillOccurrenceItem[] = [
  {
    id: 'bo_1',
    billId: 'bill_electricity',
    name: 'Electricity',
    status: 'DUE',
    dueAt: daysFromNow(1),
    expectedAmountMinor: 350000,
    currency: 'KES',
    provider: 'Kenya Power',
  },
  {
    id: 'bo_2',
    billId: 'bill_internet',
    name: 'Internet',
    status: 'UPCOMING',
    dueAt: daysFromNow(5),
    expectedAmountMinor: 450000,
    currency: 'KES',
    provider: 'Safaricom',
  },
];

const INITIAL_ACCOUNTS: AccountItem[] = [
  {
    id: 'acc_mpesa',
    name: 'M-Pesa',
    type: 'MOBILE_MONEY',
    currency: 'KES',
    currentBalanceMinor: 5000000,
  },
  {
    id: 'acc_cash',
    name: 'Cash wallet',
    type: 'CASH',
    currency: 'KES',
    currentBalanceMinor: 250000,
  },
];

const INITIAL_EXPENSES: ExpenseItem[] = [
  {
    id: 'exp_1',
    description: 'Groceries',
    amountMinor: 185000,
    currency: 'KES',
    occurredAt: daysFromNow(-1),
    merchant: 'Carrefour',
  },
  {
    id: 'exp_2',
    description: 'Fuel',
    amountMinor: 300000,
    currency: 'KES',
    occurredAt: daysFromNow(-2),
    merchant: 'Shell',
  },
];

export function useAppDataMock(): AppData {
  const [tasks, setTasks] = useState<TaskItem[]>(INITIAL_TASKS);
  const [habitOccurrences, setHabitOccurrences] = useState(INITIAL_HABITS);
  const [billOccurrences, setBillOccurrences] = useState(INITIAL_BILLS);
  const [accounts, setAccounts] = useState(INITIAL_ACCOUNTS);
  const [recentExpenses, setRecentExpenses] = useState(INITIAL_EXPENSES);
  const [recentActivity, setRecentActivity] = useState<ActivityItem[]>([
    {
      id: 'act_1',
      eventType: 'HABIT_COMPLETED',
      entityType: 'HABIT',
      title: 'Drink water (morning)',
      occurredAt: Date.now() - 45 * 60 * 1000,
    },
  ]);

  const pushActivity = useCallback((eventType: string, entityType: string, title: string) => {
    setRecentActivity((prev) => [
      {
        id: uid('act'),
        eventType,
        entityType,
        title,
        occurredAt: Date.now(),
      },
      ...prev,
    ].slice(0, 30));
  }, []);

  const completeTask = useCallback(
    (id: string) => {
      setTasks((prev) =>
        prev.map((t) => (t.id === id ? { ...t, status: 'COMPLETED' as const } : t))
      );
      const task = tasks.find((t) => t.id === id);
      if (task) pushActivity('TASK_COMPLETED', 'TASK', task.title);
    },
    [tasks, pushActivity]
  );

  const startTask = useCallback(
    (id: string) => {
      setTasks((prev) =>
        prev.map((t) => (t.id === id ? { ...t, status: 'IN_PROGRESS' as const } : t))
      );
      const task = tasks.find((t) => t.id === id);
      if (task) pushActivity('TASK_STARTED', 'TASK', task.title);
    },
    [tasks, pushActivity]
  );

  const completeHabit = useCallback(
    (id: string) => {
      setHabitOccurrences((prev) =>
        prev.map((h) => (h.id === id ? { ...h, status: 'COMPLETED' as const } : h))
      );
      const habit = habitOccurrences.find((h) => h.id === id);
      if (habit) pushActivity('HABIT_COMPLETED', 'HABIT', habit.title);
    },
    [habitOccurrences, pushActivity]
  );

  const skipHabit = useCallback(
    (id: string) => {
      setHabitOccurrences((prev) =>
        prev.map((h) => (h.id === id ? { ...h, status: 'SKIPPED' as const } : h))
      );
      const habit = habitOccurrences.find((h) => h.id === id);
      if (habit) pushActivity('HABIT_SKIPPED', 'HABIT', habit.title);
    },
    [habitOccurrences, pushActivity]
  );

  const payBill = useCallback(
    (id: string) => {
      const bill = billOccurrences.find((b) => b.id === id);
      if (!bill || bill.status === 'PAID') return;

      setBillOccurrences((prev) =>
        prev.map((b) => (b.id === id ? { ...b, status: 'PAID' as const } : b))
      );

      setAccounts((prev) =>
        prev.map((a) =>
          a.id === 'acc_mpesa'
            ? { ...a, currentBalanceMinor: a.currentBalanceMinor - bill.expectedAmountMinor }
            : a
        )
      );

      setRecentExpenses((prev) => [
        {
          id: uid('exp'),
          description: `Payment: ${bill.name}`,
          amountMinor: bill.expectedAmountMinor,
          currency: bill.currency,
          occurredAt: Date.now(),
          merchant: bill.provider ?? null,
        },
        ...prev,
      ]);

      pushActivity('BILL_PAID', 'BILL', bill.name);
    },
    [billOccurrences, pushActivity]
  );

  return useMemo(
    () => ({
      tasks,
      habitOccurrences,
      billOccurrences,
      accounts,
      recentExpenses,
      recentActivity,
      completeTask,
      startTask,
      completeHabit,
      skipHabit,
      payBill,
    }),
    [
      tasks,
      habitOccurrences,
      billOccurrences,
      accounts,
      recentExpenses,
      recentActivity,
      completeTask,
      startTask,
      completeHabit,
      skipHabit,
      payBill,
    ]
  );
}
