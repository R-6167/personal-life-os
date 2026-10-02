/// Domain models aligned with TypeScript repository-types (camelCase).
/// SQL uses snake_case; map in fromMap / toInsertMap.

class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String status;
  final int priority;
  final int? startDate;
  final int? targetDate;
  final int? completedAt;
  final String progressMode;
  final double? manualProgress;
  final int createdAt;
  final int updatedAt;
  final int? archivedAt;

  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.status,
    this.priority = 0,
    this.startDate,
    this.targetDate,
    this.completedAt,
    this.progressMode = 'CALCULATED',
    this.manualProgress,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        status: m['status'] as String,
        priority: (m['priority'] as int?) ?? 0,
        startDate: m['start_date'] as int?,
        targetDate: m['target_date'] as int?,
        completedAt: m['completed_at'] as int?,
        progressMode: (m['progress_mode'] as String?) ?? 'CALCULATED',
        manualProgress: (m['manual_progress'] as num?)?.toDouble(),
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        archivedAt: m['archived_at'] as int?,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'start_date': startDate,
        'target_date': targetDate,
        'completed_at': completedAt,
        'progress_mode': progressMode,
        'manual_progress': manualProgress,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'archived_at': archivedAt,
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
  final int? estimatedMinutes;
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
    this.estimatedMinutes,
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
        estimatedMinutes: m['estimated_minutes'] as int?,
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
        'estimated_minutes': estimatedMinutes,
        'completed_at': completedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Habit {
  final String id;
  final String ownerId;
  final String? goalId;
  final String title;
  final String? description;
  final String status;
  final int targetCount;
  final int startDate;
  final int? endDate;
  final int createdAt;
  final int updatedAt;

  const Habit({
    required this.id,
    required this.ownerId,
    this.goalId,
    required this.title,
    this.description,
    required this.status,
    this.targetCount = 1,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Habit.fromMap(Map<String, Object?> m) => Habit(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        goalId: m['goal_id'] as String?,
        title: m['title'] as String,
        description: m['description'] as String?,
        status: m['status'] as String,
        targetCount: (m['target_count'] as int?) ?? 1,
        startDate: m['start_date'] as int,
        endDate: m['end_date'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'goal_id': goalId,
        'title': title,
        'description': description,
        'status': status,
        'target_count': targetCount,
        'start_date': startDate,
        'end_date': endDate,
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
  final int? archivedAt;

  const Note({
    required this.id,
    required this.ownerId,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String?,
        content: m['content'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        archivedAt: m['archived_at'] as int?,
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'content': content,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'archived_at': archivedAt,
      };
}
