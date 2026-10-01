import { randomUUID } from 'node:crypto';
import {
  RecurrenceFrequency,
  type GeneratedOccurrences,
  type OccurrenceGenerationOptions,
  type OccurrenceInstance,
  type RecurrenceRule,
} from './recurrence-types.js';

export type RecurrenceEntityType = 'HABIT' | 'BILL' | 'TASK' | 'ROUTINE';

const DAY_IN_MS = 24 * 60 * 60 * 1000;

/**
 * Starter recurrence generator for the Personal Life OS.
 *
 * This is intentionally pragmatic: it expands a recurrence rule into concrete
 * occurrence instances for a date range without requiring a full scheduling engine.
 * It supports the recurring patterns described in the product docs:
 * - DAILY
 * - WEEKLY / BIWEEKLY
 * - MONTHLY
 * - YEARLY
 */
export class RecurrenceGenerator {
  static generateOccurrences(
    entityId: string,
    entityType: RecurrenceEntityType,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions
  ): GeneratedOccurrences {
    const from = this.normalizeDay(options.fromDate);
    const to = this.normalizeDay(options.toDate);

    if (from > to) {
      throw new Error('Occurrence generation requires fromDate <= toDate');
    }

    const occurrences: OccurrenceInstance[] = [];

    for (let cursor = from; cursor <= to; cursor += DAY_IN_MS) {
      const candidate = new Date(cursor);

      if (!this.matchesRecurrence(candidate, rule)) {
        continue;
      }

      occurrences.push({
        id: randomUUID(),
        scheduledDate: this.normalizeDay(candidate.getTime()),
        status: 'EXPECTED',
      });
    }

    return {
      entityId,
      entityType,
      occurrences,
      generatedAt: Date.now(),
      fromDate: from,
      toDate: to,
    };
  }

  private static matchesRecurrence(date: Date, rule: RecurrenceRule): boolean {
    const startDate = this.normalizeDay(rule.startDate);
    const candidateDate = this.normalizeDay(date.getTime());

    if (candidateDate < startDate) {
      return false;
    }

    if (rule.endDate && candidateDate > this.normalizeDay(rule.endDate)) {
      return false;
    }

    const diffDays = Math.floor((candidateDate - startDate) / DAY_IN_MS);
    const interval = Math.max(rule.interval || 1, 1);

    switch (rule.frequency) {
      case RecurrenceFrequency.DAILY:
        return diffDays >= 0 && diffDays % interval === 0;

      case RecurrenceFrequency.WEEKLY:
      case RecurrenceFrequency.BIWEEKLY: {
        const effectiveInterval = rule.frequency === RecurrenceFrequency.BIWEEKLY ? 2 : interval;
        const fromWeekStart = this.getWeekStart(startDate);
        const candidateWeekStart = this.getWeekStart(candidateDate);
        const weeksSinceStart = Math.floor((candidateWeekStart - fromWeekStart) / (7 * DAY_IN_MS));

        const selectedDays = rule.daysOfWeek?.length
          ? rule.daysOfWeek
          : [new Date(startDate).getDay()];

        return selectedDays.includes(date.getDay()) && weeksSinceStart % effectiveInterval === 0;
      }

      case RecurrenceFrequency.MONTHLY: {
        const dayOfMonth = rule.dayOfMonth ?? new Date(startDate).getDate();
        if (date.getDate() !== dayOfMonth) {
          return false;
        }

        const startMonthKey = this.monthKeyFromTimestamp(startDate);
        const currentMonthKey = this.monthKeyFromTimestamp(candidateDate);
        const monthDiff = currentMonthKey - startMonthKey;

        return monthDiff >= 0 && monthDiff % interval === 0;
      }

      case RecurrenceFrequency.YEARLY: {
        const monthOfYear = rule.monthOfYear ?? new Date(startDate).getMonth() + 1;
        const dayOfMonth = rule.dayOfMonth ?? new Date(startDate).getDate();

        if (date.getMonth() + 1 !== monthOfYear || date.getDate() !== dayOfMonth) {
          return false;
        }

        const yearDiff = date.getFullYear() - new Date(startDate).getFullYear();
        return yearDiff >= 0 && yearDiff % interval === 0;
      }

      case RecurrenceFrequency.CUSTOM:
        // Starter implementation treats CUSTOM as a daily recurrence with the provided interval.
        return diffDays >= 0 && diffDays % interval === 0;

      default:
        return false;
    }
  }

  private static normalizeDay(value: number): number {
    const date = new Date(value);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private static getWeekStart(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    const day = date.getDay(); // 0 = Sunday
    date.setTime(date.getTime() - day * DAY_IN_MS);
    return date.getTime();
  }

  private static monthKeyFromTimestamp(timestamp: number): number {
    const date = new Date(timestamp);
    return date.getFullYear() * 12 + (date.getMonth() + 1);
  }
}

export function generateOccurrencesForRule(
  entityId: string,
  entityType: RecurrenceEntityType,
  rule: RecurrenceRule,
  options: OccurrenceGenerationOptions
): GeneratedOccurrences {
  return RecurrenceGenerator.generateOccurrences(entityId, entityType, rule, options);
}
