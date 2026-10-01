import type Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';

import type { ActivityEvent, EventType } from '../types.js';

export interface EventRecordInput {
  ownerId: string;
  eventType: EventType;
  entityType: string;
  entityId: string;
  occurredAt?: number;
  source: string;
  metadata?: Record<string, unknown> | null;
  externalId?: string | null;
}

export class EventRecorder {
  constructor(private readonly db: Database.Database) {}

  record(input: EventRecordInput): ActivityEvent {
    const now = Date.now();
    const event: ActivityEvent = {
      id: randomUUID(),
      owner_id: input.ownerId,
      event_type: input.eventType,
      entity_type: input.entityType,
      entity_id: input.entityId,
      occurred_at: input.occurredAt ?? now,
      recorded_at: now,
      source: input.source,
      external_id: input.externalId ?? null,
      metadata: input.metadata ? JSON.stringify(input.metadata) : null,
    };

    this.db
      .prepare(
        `
        INSERT INTO activity_events (
          id, owner_id, event_type, entity_type, entity_id,
          occurred_at, recorded_at, source, external_id, metadata
        ) VALUES (
          @id, @owner_id, @event_type, @entity_type, @entity_id,
          @occurred_at, @recorded_at, @source, @external_id, @metadata
        )
        `
      )
      .run(event);

    return event;
  }
}
