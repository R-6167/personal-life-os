import type { PersonalContext } from './today-context-builder.js';

/**
 * Momentum integration contract.
 * Momentum must never depend on Personal Life OS internal tables —
 * only on this stable context shape.
 */
export interface MomentumContext {
  timestamp: number;
  availableTimeMinutes: number | null;
  activeProjects: Array<{ id: string; title: string; status: string }>;
  nextTasks: Array<{ id: string; title: string; status: string; dueAt?: number | null }>;
  upcomingEvents: Array<{ id: string; title: string; startAt: number }>;
  habitsDue: Array<{ id: string; title: string; status: string }>;
  financialObligations: Array<{
    id: string;
    name: string;
    dueAt: number;
    amountMinor?: number | null;
    currency?: string | null;
  }>;
  practicalObligations: unknown[];
  recentActivity: PersonalContext['recentActivity'];
}

export function toMomentumContext(
  context: PersonalContext,
  extras?: {
    availableTimeMinutes?: number | null;
    activeProjects?: MomentumContext['activeProjects'];
    upcomingEvents?: MomentumContext['upcomingEvents'];
  }
): MomentumContext {
  return {
    timestamp: context.currentTime,
    availableTimeMinutes: extras?.availableTimeMinutes ?? null,
    activeProjects: extras?.activeProjects ?? [],
    nextTasks: context.activeTasks.slice(0, 10).map((t) => ({
      id: t.id,
      title: t.title,
      status: t.status,
      dueAt: t.dueAt,
    })),
    upcomingEvents: extras?.upcomingEvents ?? [],
    habitsDue: context.dueHabits.map((h) => ({
      id: h.id,
      title: h.title,
      status: h.status,
    })),
    financialObligations: context.upcomingBills.map((b) => ({
      id: b.id,
      name: b.name,
      dueAt: b.dueAt,
      amountMinor: b.expectedAmountMinor,
      currency: b.currency,
    })),
    practicalObligations: [],
    recentActivity: context.recentActivity,
  };
}
