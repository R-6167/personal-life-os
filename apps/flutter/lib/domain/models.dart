import 'db_map.dart';

class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int priority;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        priority: dbIntOr(m['priority']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  /// Columns that exist in schema.sql only.
  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Project {
  final String id;
  final String ownerId;
  final String? goalId;
  final String title;
  final String status;
  final int priority;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Project({
    required this.id,
    required this.ownerId,
    this.goalId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(Map<String, Object?> m) => Project(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        goalId: dbStrOrNull(m['goal_id']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        priority: dbIntOr(m['priority']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'goal_id': goalId,
        'title': title,
        'status': status,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Milestone {
  final String id;
  final String projectId;
  final String title;
  final String status;
  final int position;
  final int createdAt;
  final int updatedAt;

  const Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: dbStr(m['id']),
        projectId: dbStr(m['project_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'PLANNED'),
        position: dbIntOr(m['position']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );
}

class Task {
  final String id;
  final String ownerId;
  final String? projectId;
  final String? goalId;
  final String? lifeAreaId;
  final String title;
  final String status;
  final int priority;
  final int? dueAt;
  final int? scheduledStart;
  final int? scheduledEnd;
  final int? estimatedMinutes;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;

  const Task({
    required this.id,
    required this.ownerId,
    this.projectId,
    this.goalId,
    this.lifeAreaId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.dueAt,
    this.scheduledStart,
    this.scheduledEnd,
    this.estimatedMinutes,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue {
    if (dueAt == null) return false;
    if (status == 'COMPLETED' || status == 'CANCELLED') return false;
    return dueAt! < DateTime.now().millisecondsSinceEpoch;
  }

  bool get isDueToday {
    if (dueAt == null) return false;
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    return dueAt! >= start && dueAt! <= end;
  }

  bool get isScheduledToday {
    if (scheduledStart == null) return false;
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    return scheduledStart! >= start && scheduledStart! <= end;
  }

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        projectId: dbStrOrNull(m['project_id']),
        goalId: dbStrOrNull(m['goal_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'INBOX'),
        priority: dbIntOr(m['priority']),
        dueAt: dbInt(m['due_at']),
        scheduledStart: dbInt(m['scheduled_start']),
        scheduledEnd: dbInt(m['scheduled_end']),
        estimatedMinutes: dbInt(m['estimated_minutes']),
        completedAt: dbInt(m['completed_at']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'project_id': projectId,
        'goal_id': goalId,
        'life_area_id': lifeAreaId,
        'title': title,
        'status': status,
        'priority': priority,
        'due_at': dueAt,
        'scheduled_start': scheduledStart,
        'scheduled_end': scheduledEnd,
        'estimated_minutes': estimatedMinutes,
        'completed_at': completedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Habit {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int targetCount;
  final int startDate;
  final int createdAt;
  final int updatedAt;

  const Habit({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.targetCount = 1,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Habit.fromMap(Map<String, Object?> m) => Habit(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        targetCount: dbIntOr(m['target_count'], 1),
        startDate: dbIntOr(m['start_date']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'target_count': targetCount,
        'start_date': startDate,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Note {
  final String id;
  final String ownerId;
  final String? title;
  final String content;
  final int createdAt;
  final int updatedAt;

  const Note({
    required this.id,
    required this.ownerId,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStrOrNull(m['title']),
        content: dbStr(m['content']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'content': content,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Expense {
  final String id;
  final String ownerId;
  final String description;
  final int amountMinor;
  final String currency;
  final int occurredAt;
  final int createdAt;
  final int updatedAt;

  const Expense({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        description: dbStr(m['description']),
        amountMinor: dbIntOr(m['amount_minor']),
        currency: dbStr(m['currency'], 'KES'),
        occurredAt: dbIntOr(m['occurred_at']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'description': description,
        'amount_minor': amountMinor,
        'currency': currency,
        'occurred_at': occurredAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  String get displayAmount => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
}

class Bill {
  final String id;
  final String ownerId;
  final String name;
  final int? expectedAmountMinor;
  final String currency;
  final int? nextDueAt;
  final String status;
  final int createdAt;
  final int updatedAt;

  const Bill({
    required this.id,
    required this.ownerId,
    required this.name,
    this.expectedAmountMinor,
    required this.currency,
    this.nextDueAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        name: dbStr(m['name']),
        expectedAmountMinor: dbInt(m['expected_amount_minor']),
        currency: dbStr(m['currency'], 'KES'),
        nextDueAt: dbInt(m['next_due_at']),
        status: dbStr(m['status'], 'ACTIVE'),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  String get displayExpected {
    if (expectedAmountMinor == null) return currency;
    return '$currency ${(expectedAmountMinor! / 100).toStringAsFixed(2)}';
  }
}

class BillOccurrence {
  final String id;
  final String billId;
  final int dueAt;
  final int? expectedAmountMinor;
  final String status;
  final String? billName;
  final String? currency;

  const BillOccurrence({
    required this.id,
    required this.billId,
    required this.dueAt,
    this.expectedAmountMinor,
    required this.status,
    this.billName,
    this.currency,
  });

  factory BillOccurrence.fromJoin(Map<String, Object?> m) => BillOccurrence(
        id: dbStr(m['id']),
        billId: dbStr(m['bill_id']),
        dueAt: dbIntOr(m['due_at']),
        expectedAmountMinor: dbInt(m['expected_amount_minor']),
        status: dbStr(m['status'], 'UPCOMING'),
        billName: dbStrOrNull(m['bill_name']),
        currency: dbStrOrNull(m['currency']),
      );
}

class Routine {
  final String id;
  final String ownerId;
  final String name;
  final String status;
  final int? estimatedMinutes;
  final int createdAt;
  final int updatedAt;

  const Routine({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    this.estimatedMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Routine.fromMap(Map<String, Object?> m) => Routine(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        name: dbStr(m['name']),
        status: dbStr(m['status'], 'ACTIVE'),
        estimatedMinutes: dbInt(m['estimated_minutes']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );
}

class Income {
  final String id;
  final String ownerId;
  final String source;
  final int amountMinor;
  final String currency;
  final int occurredAt;

  const Income({
    required this.id,
    required this.ownerId,
    required this.source,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
  });

  factory Income.fromMap(Map<String, Object?> m) => Income(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        source: dbStr(m['source']),
        amountMinor: dbIntOr(m['amount_minor']),
        currency: dbStr(m['currency'], 'KES'),
        occurredAt: dbIntOr(m['occurred_at']),
      );

  String get displayAmount => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
}
