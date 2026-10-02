import type { Db } from '../db/database';
import { DEFAULT_OWNER_ID } from '../db/database';

type Notifier = {
  requestPermissionsAsync: () => Promise<{ status: string }>;
  scheduleNotificationAsync: (opts: unknown) => Promise<string>;
  cancelAllScheduledNotificationsAsync: () => Promise<void>;
  setNotificationHandler: (h: unknown) => void;
};

let Notifications: Notifier | null = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  Notifications = require('expo-notifications');
  Notifications?.setNotificationHandler?.({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
} catch {
  Notifications = null;
}

export async function requestNotificationPermission(): Promise<boolean> {
  if (!Notifications) return false;
  const { status } = await Notifications.requestPermissionsAsync();
  return status === 'granted' || status === 'undetermined';
}

export async function syncReminderNotifications(db: Db): Promise<number> {
  if (!Notifications) return 0;
  try {
    await Notifications.cancelAllScheduledNotificationsAsync();
  } catch {
    return 0;
  }

  const granted = await requestNotificationPermission();
  if (!granted) return 0;

  const now = Date.now();
  const horizon = now + 14 * 86400000;
  const rows = await db.getAllAsync<{ id: string; title: string; body: string | null; remind_at: number }>(
    `SELECT id, title, body, remind_at FROM reminders
     WHERE owner_id = ? AND status = 'PENDING' AND remind_at > ? AND remind_at < ?
     ORDER BY remind_at ASC LIMIT 50`,
    DEFAULT_OWNER_ID,
    now,
    horizon
  );

  let scheduled = 0;
  for (const r of rows) {
    try {
      await Notifications!.scheduleNotificationAsync({
        content: {
          title: r.title,
          body: r.body || 'Reminder from Personal Life OS',
          data: { reminderId: r.id },
        },
        trigger: {
          type: 'date',
          date: new Date(r.remind_at),
        },
      });
      scheduled += 1;
    } catch {
      /* ignore */
    }
  }
  return scheduled;
}
