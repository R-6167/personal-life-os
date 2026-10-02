import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AppData } from '../types/app-data';
import { getDatabase } from '../db/database';
import * as Q from '../db/queries';
import * as L from '../db/life-queries';
import { ensureHabitOccurrences } from '../habits/recurrence';

const empty = {
  tasks: [],
  habitOccurrences: [],
  billOccurrences: [],
  accounts: [],
  recentExpenses: [],
  recentActivity: [],
  goals: [],
  projects: [],
  notes: [],
  events: [],
  reminders: [],
  inbox: [],
  milestones: [],
};

export function useAppDataSQLite(): AppData {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState(empty);

  const refresh = useCallback(async () => {
    try {
      const db = await getDatabase();
      await ensureHabitOccurrences(db, { daysAhead: 0 });
      const [
        tasks,
        habitOccurrences,
        billOccurrences,
        accounts,
        recentExpenses,
        recentActivity,
        goals,
        projects,
        notes,
        events,
        reminders,
        inbox,
        milestones,
      ] = await Promise.all([
        Q.loadTasks(db),
        Q.loadHabitOccurrences(db),
        Q.loadBillOccurrences(db),
        Q.loadAccounts(db),
        Q.loadExpenses(db),
        Q.loadActivity(db),
        Q.loadGoals(db),
        Q.loadProjects(db),
        L.loadNotes(db),
        L.loadEvents(db),
        L.loadReminders(db),
        L.loadInbox(db),
        L.loadMilestones(db),
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
        notes,
        events,
        reminders,
        inbox,
        milestones,
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
  const createNote = useCallback(
    (input: Parameters<AppData['createNote']>[0]) =>
      withRefresh(async () => {
        await L.createNote(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const toggleNotePin = useCallback(
    (id: string) => withRefresh(async () => L.toggleNotePin(await getDatabase(), id)),
    [withRefresh]
  );
  const createEvent = useCallback(
    (input: Parameters<AppData['createEvent']>[0]) =>
      withRefresh(async () => {
        await L.createEvent(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const createReminder = useCallback(
    (input: Parameters<AppData['createReminder']>[0]) =>
      withRefresh(async () => {
        await L.createReminder(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const completeReminder = useCallback(
    (id: string) => withRefresh(async () => L.completeReminder(await getDatabase(), id)),
    [withRefresh]
  );
  const captureInbox = useCallback(
    (rawText: string, suggestedType?: string) =>
      withRefresh(async () => {
        await L.captureInbox(await getDatabase(), rawText, suggestedType);
      }),
    [withRefresh]
  );
  const processInboxToTask = useCallback(
    (id: string) => withRefresh(async () => { await L.processInboxToTask(await getDatabase(), id); }),
    [withRefresh]
  );
  const processInboxToNote = useCallback(
    (id: string) => withRefresh(async () => { await L.processInboxToNote(await getDatabase(), id); }),
    [withRefresh]
  );
  const dismissInbox = useCallback(
    (id: string) => withRefresh(async () => L.dismissInbox(await getDatabase(), id)),
    [withRefresh]
  );
  const createMilestone = useCallback(
    (input: Parameters<AppData['createMilestone']>[0]) =>
      withRefresh(async () => {
        await L.createMilestone(await getDatabase(), input);
      }),
    [withRefresh]
  );
  const completeMilestone = useCallback(
    (id: string) => withRefresh(async () => L.completeMilestone(await getDatabase(), id)),
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
      createNote,
      toggleNotePin,
      createEvent,
      createReminder,
      completeReminder,
      captureInbox,
      processInboxToTask,
      processInboxToNote,
      dismissInbox,
      createMilestone,
      completeMilestone,
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
      createNote,
      toggleNotePin,
      createEvent,
      createReminder,
      completeReminder,
      captureInbox,
      processInboxToTask,
      processInboxToNote,
      dismissInbox,
      createMilestone,
      completeMilestone,
    ]
  );
}
