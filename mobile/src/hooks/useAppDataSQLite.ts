import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AppData } from '../types/app-data';
import { getDatabase } from '../db/database';
import * as Q from '../db/queries';
import { ensureHabitOccurrences } from '../habits/recurrence';

const empty: Omit<
  AppData,
  | 'ready'
  | 'error'
  | 'refresh'
  | 'completeTask'
  | 'startTask'
  | 'createTask'
  | 'completeHabit'
  | 'skipHabit'
  | 'createHabit'
  | 'payBill'
  | 'createGoal'
  | 'createProject'
> = {
  tasks: [],
  habitOccurrences: [],
  billOccurrences: [],
  accounts: [],
  recentExpenses: [],
  recentActivity: [],
  goals: [],
  projects: [],
};

export function useAppDataSQLite(): AppData {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState(empty);

  const refresh = useCallback(async () => {
    try {
      const db = await getDatabase();
      await ensureHabitOccurrences(db, { daysAhead: 0 });
      const [tasks, habitOccurrences, billOccurrences, accounts, recentExpenses, recentActivity, goals, projects] =
        await Promise.all([
          Q.loadTasks(db),
          Q.loadHabitOccurrences(db),
          Q.loadBillOccurrences(db),
          Q.loadAccounts(db),
          Q.loadExpenses(db),
          Q.loadActivity(db),
          Q.loadGoals(db),
          Q.loadProjects(db),
        ]);
      setData({
        tasks,
        habitOccurrences,
        billOccurrences,
        accounts,
        recentExpenses,
        recentActivity,
        goals,
        projects,
      });
      setError(null);
      setReady(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setReady(true);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const withRefresh = useCallback(
    async (fn: () => Promise<void>) => {
      await fn();
      await refresh();
    },
    [refresh]
  );

  const completeTask = useCallback(
    (id: string) => withRefresh(async () => Q.completeTask(await getDatabase(), id)),
    [withRefresh]
  );
  const startTask = useCallback(
    (id: string) => withRefresh(async () => Q.startTask(await getDatabase(), id)),
    [withRefresh]
  );
  const createTask = useCallback(
    (input: Parameters<AppData['createTask']>[0]) =>
      withRefresh(async () => {
        await Q.createTask(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const completeHabit = useCallback(
    (id: string) => withRefresh(async () => Q.completeHabitOccurrence(await getDatabase(), id)),
    [withRefresh]
  );
  const skipHabit = useCallback(
    (id: string) => withRefresh(async () => Q.skipHabitOccurrence(await getDatabase(), id)),
    [withRefresh]
  );
  const createHabit = useCallback(
    (input: Parameters<AppData['createHabit']>[0]) =>
      withRefresh(async () => {
        await Q.createHabit(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const payBill = useCallback(
    (id: string) => withRefresh(async () => Q.payBillOccurrence(await getDatabase(), id)),
    [withRefresh]
  );
  const createGoal = useCallback(
    (input: Parameters<AppData['createGoal']>[0]) =>
      withRefresh(async () => {
        await Q.createGoal(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const createProject = useCallback(
    (input: Parameters<AppData['createProject']>[0]) =>
      withRefresh(async () => {
        await Q.createProject(await getDatabase(), input);
      }),
    [withRefresh]
  );

  return useMemo(
    () => ({
      ready,
      error,
      ...data,
      refresh,
      completeTask,
      startTask,
      createTask,
      completeHabit,
      skipHabit,
      createHabit,
      payBill,
      createGoal,
      createProject,
    }),
    [
      ready,
      error,
      data,
      refresh,
      completeTask,
      startTask,
      createTask,
      completeHabit,
      skipHabit,
      createHabit,
      payBill,
      createGoal,
      createProject,
    ]
  );
}
