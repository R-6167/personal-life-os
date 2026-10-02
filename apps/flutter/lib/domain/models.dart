class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String status;
  final int priority;
  final int createdAt;
  final int updatedAt;

  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.status,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        status: m['status'] as String,
        priority: (m['priority'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
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

  const Project({
    required this.id,
    required this.ownerId,
    this.goalId,
    required this.title,
    required this.status,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
  });

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

class Task {
  final String id;
  final String ownerId;
  final String? projectId;
  final String? goalId;
  final String title;
  final String? description;
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
    this.description,
    required this.status,
    this.priority = 0,
    this.dueAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        projectId: m['project_id'] as String?,
        goalId: m['goal_id'] as String?,
        title: m['title'] as String,
        description: m['description'] as String?,
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
        'description': description,
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

  const Note({
    required this.id,
    required this.ownerId,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

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
  final String? merchant;
  final int createdAt;
  final int updatedAt;

  const Expense({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    this.merchant,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        description: m['description'] as String,
        amountMinor: m['amount_minor'] as int,
        currency: m['currency'] as String,
        occurredAt: m['occurred_at'] as int,
        merchant: m['merchant'] as String?,
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
        'merchant': merchant,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Display amount assuming 100 minor units = 1 major (KES, USD, …).
  String get displayAmount {
    final major = amountMinor / 100.0;
    return '$currency ${major.toStringAsFixed(2)}';
  }
}
