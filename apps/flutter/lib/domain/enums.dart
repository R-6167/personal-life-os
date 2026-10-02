/// Status / type strings — must match contract/enums.json and TypeScript.
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
  static const weekStartDay = 1; // Monday
}
