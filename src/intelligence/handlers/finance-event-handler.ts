import { EventRecorder } from './event-recorder.js';
import {
  FinanceEventType,
  EntityType,
  EventSource,
  ExpenseRecordedMetadata,
  BillPaidMetadata,
} from '../types/events.js';

/**
 * FinanceEventHandler manages events for finance-related operations.
 */
export class FinanceEventHandler {
  constructor(private recorder: EventRecorder) {}

  /**
   * Record an income recorded event.
   */
  recordIncomeRecorded(
    ownerId: string,
    incomeId: string,
    amount: number,
    currency: string,
    source?: string,
    metadata?: Record<string, unknown>
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.INCOME_RECORDED,
      entityType: EntityType.INCOME,
      entityId: incomeId,
      source: EventSource.USER,
      metadata: {
        amount,
        currency,
        source,
        ...metadata,
      },
    });
  }

  /**
   * Record an expense recorded event.
   */
  recordExpenseRecorded(
    ownerId: string,
    expenseId: string,
    amount: number,
    currency: string,
    merchant?: string,
    paymentMethod?: string,
    categoryId?: string
  ) {
    const metadata: ExpenseRecordedMetadata = {
      amount,
      currency,
      merchant,
      paymentMethod,
      categoryId,
    };

    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.EXPENSE_RECORDED,
      entityType: EntityType.EXPENSE,
      entityId: expenseId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a bill created event.
   */
  recordBillCreated(ownerId: string, billId: string, metadata?: Record<string, unknown>) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.BILL_CREATED,
      entityType: EntityType.BILL,
      entityId: billId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a bill due event (system-generated).
   * This would typically be triggered by a scheduler/job.
   */
  recordBillDue(
    ownerId: string,
    billOccurrenceId: string,
    billId: string,
    expectedAmount?: number,
    currency?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.BILL_DUE,
      entityType: EntityType.BILL_OCCURRENCE,
      entityId: billOccurrenceId,
      source: EventSource.SYSTEM,
      metadata: {
        billId,
        expectedAmount,
        currency,
      },
    });
  }

  /**
   * Record a bill paid event.
   */
  recordBillPaid(
    ownerId: string,
    billOccurrenceId: string,
    billId: string,
    amount: number,
    currency: string,
    paymentMethod?: string,
    accountId?: string
  ) {
    const metadata: BillPaidMetadata = {
      amount,
      currency,
      paymentMethod,
      accountId,
    };

    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.BILL_PAID,
      entityType: EntityType.BILL_OCCURRENCE,
      entityId: billOccurrenceId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a bill overdue event (system-generated).
   */
  recordBillOverdue(
    ownerId: string,
    billOccurrenceId: string,
    billId: string,
    daysOverdue: number
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.BILL_OVERDUE,
      entityType: EntityType.BILL_OCCURRENCE,
      entityId: billOccurrenceId,
      source: EventSource.SYSTEM,
      metadata: {
        billId,
        daysOverdue,
      },
    });
  }

  /**
   * Record a subscription created event.
   */
  recordSubscriptionCreated(
    ownerId: string,
    subscriptionId: string,
    metadata?: Record<string, unknown>
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.SUBSCRIPTION_CREATED,
      entityType: EntityType.SUBSCRIPTION,
      entityId: subscriptionId,
      source: EventSource.USER,
      metadata,
    });
  }

  /**
   * Record a subscription renewed event.
   */
  recordSubscriptionRenewed(
    ownerId: string,
    subscriptionId: string,
    amount: number,
    currency: string,
    nextRenewalAt: number
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.SUBSCRIPTION_RENEWED,
      entityType: EntityType.SUBSCRIPTION,
      entityId: subscriptionId,
      source: EventSource.SYSTEM,
      metadata: {
        amount,
        currency,
        nextRenewalAt,
      },
    });
  }

  /**
   * Record a subscription cancelled event.
   */
  recordSubscriptionCancelled(
    ownerId: string,
    subscriptionId: string,
    reason?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.SUBSCRIPTION_CANCELLED,
      entityType: EntityType.SUBSCRIPTION,
      entityId: subscriptionId,
      source: EventSource.USER,
      metadata: reason ? { reason } : undefined,
    });
  }

  /**
   * Record a debt payment recorded event.
   */
  recordDebtPaymentRecorded(
    ownerId: string,
    debtPaymentId: string,
    debtId: string,
    amount: number,
    currency: string,
    accountId?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.DEBT_PAYMENT_RECORDED,
      entityType: EntityType.DEBT_PAYMENT,
      entityId: debtPaymentId,
      source: EventSource.USER,
      metadata: {
        debtId,
        amount,
        currency,
        accountId,
      },
    });
  }

  /**
   * Record a savings contribution recorded event.
   */
  recordSavingsContributionRecorded(
    ownerId: string,
    contributionId: string,
    savingsGoalId: string,
    amount: number,
    currency: string,
    accountId?: string
  ) {
    return this.recorder.recordEvent({
      ownerId,
      eventType: FinanceEventType.SAVINGS_CONTRIBUTION_RECORDED,
      entityType: EntityType.SAVINGS_CONTRIBUTION,
      entityId: contributionId,
      source: EventSource.USER,
      metadata: {
        savingsGoalId,
        amount,
        currency,
        accountId,
      },
    });
  }
}
