class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int priority;
  final int createdAt;
  final int updatedAt;

  const Goal({required this.id, required this.ownerId, required this.title, required this.status, this.priority = 0, required this.createdAt, required this.updatedAt});

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        status: m['status'] as String,
        priority: (m['priority'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'priority': priority,
        'progress_mode': 'CALCULATED',
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
  final int createdAt;
  final int updatedAt;

  const Project({required this.id, required this.ownerId, this.goalId, required this.title, required this.status, this.priority = 0, required this.createdAt, required this.updatedAt});

  factory Project.fromMap(Map<String, Object?> m) => Project(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        goalId: m['goal_id'] as String?,
        title: m['title'] as String,
        status: m['status'] as String,
        priority: (m['priority'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'goal_id': goalId,
        'title': title,
        'status': status,
        'priority': priority,
        'progress_mode': 'CALCULATED',
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

  const Milestone({required this.id, required this.projectId, required this.title, required this.status, this.position = 0, required this.createdAt, required this.updatedAt});

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        title: m['title'] as String,
        status: m['status'] as String,
        position: (m['position'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}

class Task {
  final String id;
  final String ownerId;
  final String? projectId;
  final String? goalId;
  final String title;
  final String status;
  final int priority;
  final int? dueAt;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;

  const Task({
    required this.id,
    required this.ownerId,
    this.projectId,
    this.goalId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.dueAt,
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

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        projectId: m['project_id'] as String?,
        goalId: m['goal_id'] as String?,
        title: m['title'] as String,
        status: m['status'] as String,
        priority: (m['priority'] as int?) ?? 0,
        dueAt: m['due_at'] as int?,
        completedAt: m['completed_at'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'project_id': projectId,
        'goal_id': goalId,
        'title': title,
        'status': status,
        'priority': priority,
        'due_at': dueAt,
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

  const Habit({required this.id, required this.ownerId, required this.title, required this.status, this.targetCount = 1, required this.startDate, required this.createdAt, required this.updatedAt});

  factory Habit.fromMap(Map<String, Object?> m) => Habit(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        status: m['status'] as String,
        targetCount: (m['target_count'] as int?) ?? 1,
        startDate: m['start_date'] as int,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
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

  const Note({required this.id, required this.ownerId, this.title, required this.content, required this.createdAt, required this.updatedAt});

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String?,
        content: m['content'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
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

  const Expense({required this.id, required this.ownerId, required this.description, required this.amountMinor, required this.currency, required this.occurredAt, required this.createdAt, required this.updatedAt});

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        description: m['description'] as String,
        amountMinor: m['amount_minor'] as int,
        currency: m['currency'] as String,
        occurredAt: m['occurred_at'] as int,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
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

  const Bill({required this.id, required this.ownerId, required this.name, this.expectedAmountMinor, required this.currency, this.nextDueAt, required this.status, required this.createdAt, required this.updatedAt});

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: m['name'] as String,
        expectedAmountMinor: m['expected_amount_minor'] as int?,
        currency: m['currency'] as String,
        nextDueAt: m['next_due_at'] as int?,
        status: m['status'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
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

  const BillOccurrence({required this.id, required this.billId, required this.dueAt, this.expectedAmountMinor, required this.status, this.billName, this.currency});

  factory BillOccurrence.fromJoin(Map<String, Object?> m) => BillOccurrence(
        id: m['id'] as String,
        billId: m['bill_id'] as String,
        dueAt: m['due_at'] as int,
        expectedAmountMinor: m['expected_amount_minor'] as int?,
        status: m['status'] as String,
        billName: m['bill_name'] as String?,
        currency: m['currency'] as String?,
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

  const Routine({required this.id, required this.ownerId, required this.name, required this.status, this.estimatedMinutes, required this.createdAt, required this.updatedAt});

  factory Routine.fromMap(Map<String, Object?> m) => Routine(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: m['name'] as String,
        status: m['status'] as String,
        estimatedMinutes: m['estimated_minutes'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}

class Income {
  final String id;
  final String ownerId;
  final String source;
  final int amountMinor;
  final String currency;
  final int occurredAt;

  const Income({required this.id, required this.ownerId, required this.source, required this.amountMinor, required this.currency, required this.occurredAt});

  factory Income.fromMap(Map<String, Object?> m) => Income(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        source: m['source'] as String,
        amountMinor: m['amount_minor'] as int,
        currency: m['currency'] as String,
        occurredAt: m['occurred_at'] as int,
      );

  String get displayAmount => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
}
