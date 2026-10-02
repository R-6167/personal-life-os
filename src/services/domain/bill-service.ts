import Database from 'better-sqlite3';
import { EventBus } from '../../intelligence/event-bus.js';
import { BillRepository } from '../repositories/bill-repository.js';
import { FinanceRepository } from '../repositories/finance-repository.js';
import { OccurrenceService } from '../occurrences/occurrence-service.js';
import type { BillRecord, BillOccurrenceRecord, ExpenseRecord } from '../repositories/repository-types.js';
import type { RecurrenceRule, OccurrenceGenerationOptions } from '../recurrence/recurrence-types.js';
import { FinanceEventType, EntityType, EventSource } from '../../types/events.js';
import { nowMs } from '../repositories/repository-types.js';

export class BillService {
  private readonly bills: BillRepository;
  private readonly finance: FinanceRepository;
  private readonly occurrences: OccurrenceService;
  private readonly bus: EventBus;

  constructor(db: Database.Database, bus?: EventBus) {
    this.bills = new BillRepository(db);
    this.finance = new FinanceRepository(db);
    this.occurrences = new OccurrenceService(db);
    this.bus = bus ?? new EventBus(db);
  }

  create(
    input: Omit<BillRecord, 'id' | 'createdAt' | 'updatedAt' | 'archivedAt'> & { id?: string }
  ): BillRecord {
    return this.bus.transaction((bus) => {
      const bill = this.bills.create(input);
      bus.recordEvent({
        ownerId: bill.ownerId,
        eventType: FinanceEventType.BILL_CREATED,
        entityType: EntityType.BILL,
        entityId: bill.id,
        source: EventSource.USER,
        metadata: { name: bill.name, currency: bill.currency },
      });
      return bill;
    });
  }

  generateOccurrences(
    billId: string,
    rule: RecurrenceRule,
    options: OccurrenceGenerationOptions,
    expectedAmountMinor?: number | null
  ) {
    return this.occurrences.generateBillOccurrencesForRule(
      billId,
      rule,
      options,
      expectedAmountMinor ?? null
    );
  }

  /**
   * Pay a bill occurrence: mark paid, create expense, adjust account balance, log events.
   */
  payOccurrence(
    occurrenceId: string,
    opts: {
      amountMinor: number;
      currency: string;
      accountId?: string;
      paymentMethod?: string;
      description?: string;
    }
  ): { occurrence: BillOccurrenceRecord; expense: ExpenseRecord } {
    return this.bus.transaction((bus) => {
      const occ = this.bills.findOccurrenceById(occurrenceId);
      if (!occ) throw new Error(`Bill occurrence not found: ${occurrenceId}`);
      if (occ.status === 'PAID') throw new Error('Bill occurrence already paid');

      const bill = this.bills.findById(occ.billId);
      if (!bill) throw new Error(`Bill not found: ${occ.billId}`);

      const accountId = opts.accountId ?? bill.defaultAccountId ?? null;

      const expense = this.finance.createExpense({
        ownerId: bill.ownerId,
        accountId,
        categoryId: bill.categoryId ?? null,
        merchant: bill.provider ?? null,
        description: opts.description ?? `Payment: ${bill.name}`,
        amountMinor: opts.amountMinor,
        currency: opts.currency,
        occurredAt: nowMs(),
        paymentMethod: opts.paymentMethod ?? null,
      });

      if (accountId) {
        this.finance.adjustAccountBalance(accountId, -opts.amountMinor);
      }

      const updated = this.bills.markOccurrencePaid(occurrenceId, opts.amountMinor, expense.id);
      if (!updated) throw new Error(`Failed to mark occurrence paid: ${occurrenceId}`);

      bus.recordEvent({
        ownerId: bill.ownerId,
        eventType: FinanceEventType.BILL_PAID,
        entityType: EntityType.BILL_OCCURRENCE,
        entityId: occurrenceId,
        source: EventSource.USER,
        metadata: {
          billId: bill.id,
          amount: opts.amountMinor,
          currency: opts.currency,
          paymentMethod: opts.paymentMethod,
          accountId,
          expenseId: expense.id,
        },
      });

      bus.recordEvent({
        ownerId: bill.ownerId,
        eventType: FinanceEventType.EXPENSE_RECORDED,
        entityType: EntityType.EXPENSE,
        entityId: expense.id,
        source: EventSource.USER,
        metadata: {
          amount: opts.amountMinor,
          currency: opts.currency,
          merchant: bill.provider,
          paymentMethod: opts.paymentMethod,
        },
      });

      return { occurrence: updated, expense };
    });
  }

  findById(id: string): BillRecord | null {
    return this.bills.findById(id);
  }

  listOpenOccurrences(ownerId: string, beforeMs?: number): BillOccurrenceRecord[] {
    return this.bills.listOpenOccurrences(ownerId, beforeMs);
  }
}

export function createBillService(db: Database.Database, bus?: EventBus): BillService {
  return new BillService(db, bus);
}
