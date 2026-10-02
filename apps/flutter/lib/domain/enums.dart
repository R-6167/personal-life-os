library;

class EntityStatus {
  static const active = 'ACTIVE';
  static const inbox = 'INBOX';
  static const planned = 'PLANNED';
  static const inProgress = 'IN_PROGRESS';
  static const waiting = 'WAITING';
  static const completed = 'COMPLETED';
  static const paused = 'PAUSED';
  static const cancelled = 'CANCELLED';
  static const archived = 'ARCHIVED';
}

class HabitOccurrenceStatus {
  static const expected = 'EXPECTED';
  static const completed = 'COMPLETED';
  static const missed = 'MISSED';
  static const skipped = 'SKIPPED';
  static const partial = 'PARTIAL';
}

class BillOccurrenceStatus {
  static const upcoming = 'UPCOMING';
  static const due = 'DUE';
  static const overdue = 'OVERDUE';
  static const paid = 'PAID';
  static const cancelled = 'CANCELLED';
}

class BillStatus {
  static const active = 'ACTIVE';
  static const paused = 'PAUSED';
  static const cancelled = 'CANCELLED';
}

class MilestoneStatus {
  static const planned = 'PLANNED';
  static const inProgress = 'IN_PROGRESS';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
}

class RoutineOccurrenceStatus {
  static const expected = 'EXPECTED';
  static const started = 'STARTED';
  static const completed = 'COMPLETED';
  static const missed = 'MISSED';
  static const skipped = 'SKIPPED';
}

class ProgressMode {
  static const calculated = 'CALCULATED';
  static const manual = 'MANUAL';
}

class EventSource {
  static const user = 'USER';
  static const system = 'SYSTEM';
}

class Defaults {
  static const currency = 'KES';
  static const locale = 'en';
  static const weekStartDay = 1;
}
