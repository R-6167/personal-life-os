import Database from 'better-sqlite3';
import { v4 as uuidv4 } from 'uuid';
import {
  ActivityEvent,
  CreateEventParams,
  EventLogEntry,
  EventSource,
} from '../types/events.js';

/**
 * EventRecorder manages the immutable activity event log.
 * 
 * Responsibilities:
 * - Record events atomically with their entity changes
 * - Ensure idempotency via external IDs
 * - Support transactional writes (event + entity update together)
 * - Maintain immutability (events are write-once)
 * - Distinguish between occurredAt (when it happened) and recordedAt (when we logged it)
 */
export class EventRecorder {
  private db: Database.Database;

  constructor(db: Database.Database) {
    this.db = db;
  }

  /**
   * Record a single event.
   * Does NOT update the related entity - that's handled by domain services
   * in transactional contexts.
   */
  recordEvent(params: CreateEventParams): EventLogEntry {
    const now = Date.now();
    const event: EventLogEntry = {
      id: uuidv4(),
      ownerId: params.ownerId,
      eventType: params.eventType,
      entityType: params.entityType,
      entityId: params.entityId,
      occurredAt: params.occurredAt ?? now,
      recordedAt: now,
      source: params.source ?? EventSource.USER,
      externalId: params.externalId,
      metadata: params.metadata,
    };

    const stmt = this.db.prepare(`
      INSERT INTO activity_events (
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      event.id,
      event.ownerId,
      event.eventType,
      event.entityType,
      event.entityId,
      event.occurredAt,
      event.recordedAt,
      event.source,
      event.externalId ?? null,
      event.metadata ? JSON.stringify(event.metadata) : null
    );

    return event;
  }

  /**
   * Record multiple events atomically.
   * Useful for complex operations that should log multiple related events.
   */
  recordEvents(eventParams: CreateEventParams[]): EventLogEntry[] {
    const events = eventParams.map((params) => {
      const now = Date.now();
      return {
        id: uuidv4(),
        ownerId: params.ownerId,
        eventType: params.eventType,
        entityType: params.entityType,
        entityId: params.entityId,
        occurredAt: params.occurredAt ?? now,
        recordedAt: now,
        source: params.source ?? EventSource.USER,
        externalId: params.externalId,
        metadata: params.metadata,
      } as EventLogEntry;
    });

    const insertStmt = this.db.prepare(`
      INSERT INTO activity_events (
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    for (const event of events) {
      insertStmt.run(
        event.id,
        event.ownerId,
        event.eventType,
        event.entityType,
        event.entityId,
        event.occurredAt,
        event.recordedAt,
        event.source,
        event.externalId ?? null,
        event.metadata ? JSON.stringify(event.metadata) : null
      );
    }

    return events;
  }

  /**
   * Execute a function within a transaction, recording events together with
   * the entity changes they describe.
   * 
   * This ensures atomicity: either both the entity update and events are recorded,
   * or neither are.
   */
  transaction<T>(
    fn: (recorder: EventRecorder) => T
  ): T {
    const transactionFn = this.db.transaction((innerRecorder: EventRecorder) => fn(innerRecorder));
    return transactionFn(this);
  }

  /**
   * Query events for a specific owner and entity.
   */
  getEventsByEntity(
    ownerId: string,
    entityType: string,
    entityId: string
  ): EventLogEntry[] {
    const stmt = this.db.prepare(`
      SELECT 
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      FROM activity_events
      WHERE owner_id = ? AND entity_type = ? AND entity_id = ?
      ORDER BY occurred_at ASC
    `);

    const rows = stmt.all(ownerId, entityType, entityId) as any[];
    return rows.map((row) => this.parseEventRow(row));
  }

  /**
   * Query events by owner and event type (e.g., all TASK_COMPLETED events).
   */
  getEventsByType(ownerId: string, eventType: string, limit = 100): EventLogEntry[] {
    const stmt = this.db.prepare(`
      SELECT 
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      FROM activity_events
      WHERE owner_id = ? AND event_type = ?
      ORDER BY occurred_at DESC
      LIMIT ?
    `);

    const rows = stmt.all(ownerId, eventType, limit) as any[];
    return rows.map((row) => this.parseEventRow(row));
  }

  /**
   * Query events in a time range.
   */
  getEventsByTimeRange(
    ownerId: string,
    startTime: number,
    endTime: number,
    limit = 1000
  ): EventLogEntry[] {
    const stmt = this.db.prepare(`
      SELECT 
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      FROM activity_events
      WHERE owner_id = ? AND occurred_at >= ? AND occurred_at <= ?
      ORDER BY occurred_at DESC
      LIMIT ?
    `);

    const rows = stmt.all(ownerId, startTime, endTime, limit) as any[];
    return rows.map((row) => this.parseEventRow(row));
  }

  /**
   * Get the most recent events for an owner (useful for activity stream/today).
   */
  getRecentEvents(ownerId: string, limit = 50): EventLogEntry[] {
    const stmt = this.db.prepare(`
      SELECT 
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      FROM activity_events
      WHERE owner_id = ?
      ORDER BY occurred_at DESC
      LIMIT ?
    `);

    const rows = stmt.all(ownerId, limit) as any[];
    return rows.map((row) => this.parseEventRow(row));
  }

  /**
   * Check if an external event has already been imported (idempotency).
   */
  hasExternalEvent(source: string, externalId: string): boolean {
    const stmt = this.db.prepare(`
      SELECT 1 FROM activity_events
      WHERE source = ? AND external_id = ?
      LIMIT 1
    `);

    return stmt.get(source, externalId) !== undefined;
  }

  /**
   * Get event by ID.
   */
  getEventById(id: string): EventLogEntry | null {
    const stmt = this.db.prepare(`
      SELECT 
        id, owner_id, event_type, entity_type, entity_id,
        occurred_at, recorded_at, source, external_id, metadata
      FROM activity_events
      WHERE id = ?
    `);

    const row = stmt.get(id) as any;
    return row ? this.parseEventRow(row) : null;
  }

  /**
   * Count events by type (useful for statistics/insights).
   */
  countEventsByType(ownerId: string, eventType: string): number {
    const stmt = this.db.prepare(`
      SELECT COUNT(*) as count FROM activity_events
      WHERE owner_id = ? AND event_type = ?
    `);

    const result = stmt.get(ownerId, eventType) as { count: number };
    return result.count;
  }

  /**
   * Count all events for an owner.
   */
  countAllEvents(ownerId: string): number {
    const stmt = this.db.prepare(`
      SELECT COUNT(*) as count FROM activity_events
      WHERE owner_id = ?
    `);

    const result = stmt.get(ownerId) as { count: number };
    return result.count;
  }

  /**
   * Parse a database row into an EventLogEntry, handling JSON metadata.
   */
  private parseEventRow(row: any): EventLogEntry {
    return {
      id: row.id,
      ownerId: row.owner_id,
      eventType: row.event_type,
      entityType: row.entity_type,
      entityId: row.entity_id,
      occurredAt: row.occurred_at,
      recordedAt: row.recorded_at,
      source: row.source,
      externalId: row.external_id,
      metadata: row.metadata ? JSON.parse(row.metadata) : undefined,
    };
  }
}
