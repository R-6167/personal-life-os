import '../data/database.dart';
import '../data/task_repository.dart';
import '../domain/db_map.dart';
import '../domain/enums.dart';

/// Full work loop:
/// Scheduled → Started → Worked → Paused/interrupted → Completed → Actual duration → History
class WorkSession {
  final String id;
  final String? taskId;
  final String? timeBlockId;
  final String status; // RUNNING | PAUSED | COMPLETED | INTERRUPTED | CANCELLED
  final int? plannedMinutes;
  final int startedAt;
  final int? endedAt;
  final int? pausedAt;
  final int accumulatedMs;
  final int interruptCount;
  final String? note;
  final String? taskTitle;

  const WorkSession({
    required this.id,
    this.taskId,
    this.timeBlockId,
    required this.status,
    this.plannedMinutes,
    required this.startedAt,
    this.endedAt,
    this.pausedAt,
    required this.accumulatedMs,
    required this.interruptCount,
    this.note,
    this.taskTitle,
  });

  /// Live elapsed including current run segment if RUNNING.
  int elapsedMs({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (status == 'RUNNING') {
      return accumulatedMs + n.millisecondsSinceEpoch - startedAt;
    }
    if (status == 'PAUSED' && pausedAt != null) {
      // accumulated already excludes current pause
      return accumulatedMs;
    }
    return accumulatedMs;
  }

  int get actualMinutes => (elapsedMs() / 60000).round();

  factory WorkSession.fromMap(Map<String, Object?> m, {String? taskTitle}) {
    return WorkSession(
      id: dbStr(m['id']),
      taskId: dbStrOrNull(m['task_id']),
      timeBlockId: dbStrOrNull(m['time_block_id']),
      status: dbStr(m['status'], 'RUNNING'),
      plannedMinutes: m['planned_minutes'] as int?,
      startedAt: dbIntOr(m['started_at']),
      endedAt: m['ended_at'] as int?,
      pausedAt: m['paused_at'] as int?,
      accumulatedMs: dbIntOr(m['accumulated_ms']),
      interruptCount: dbIntOr(m['interrupt_count']),
      note: dbStrOrNull(m['note']),
      taskTitle: taskTitle,
    );
  }
}

class EstimateInsight {
  final int sampleCount;
  final double avgActualMinutes;
  final double avgPlannedMinutes;
  final double ratio; // actual / planned

  const EstimateInsight({
    required this.sampleCount,
    required this.avgActualMinutes,
    required this.avgPlannedMinutes,
    required this.ratio,
  });

  String get summary {
    if (sampleCount == 0) return 'Not enough history yet';
    final pct = ((ratio - 1) * 100).round();
    if (ratio > 1.15) {
      return 'Usually takes ~${avgActualMinutes.round()}m (about ${pct}% longer than planned)';
    }
    if (ratio < 0.85) {
      return 'Usually finishes in ~${avgActualMinutes.round()}m (faster than planned)';
    }
    return 'Estimates are close — about ${avgActualMinutes.round()}m on average';
  }
}

class WorkSessionService {
  WorkSessionService([AppDatabase? db]) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<WorkSession?> activeSession({String? taskId}) async {
    final db = await _db.database;
    final rows = await db.query(
      'work_sessions',
      where: taskId == null
          ? "status IN ('RUNNING','PAUSED')"
          : "task_id = ? AND status IN ('RUNNING','PAUSED')",
      whereArgs: taskId == null ? null : [taskId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkSession.fromMap(rows.first);
  }

  Future<List<WorkSession>> historyForTask(String taskId, {int limit = 20}) async {
    final db = await _db.database;
    final rows = await db.query(
      'work_sessions',
      where: "task_id = ? AND status = 'COMPLETED'",
      whereArgs: [taskId],
      orderBy: 'ended_at DESC',
      limit: limit,
    );
    return rows.map((m) => WorkSession.fromMap(m)).toList();
  }

  Future<List<WorkSession>> recentCompleted({int limit = 30}) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT w.*, t.title AS task_title
      FROM work_sessions w
      LEFT JOIN tasks t ON t.id = w.task_id
      WHERE w.status = 'COMPLETED'
      ORDER BY w.ended_at DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((m) => WorkSession.fromMap(m, taskTitle: dbStrOrNull(m['task_title'])))
        .toList();
  }

  /// Start work on a task (or generic focus). Pauses any other running session.
  Future<WorkSession> start({
    String? taskId,
    String? timeBlockId,
    int? plannedMinutes,
  }) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();

    // Interrupt other active sessions
    final active = await db.query(
      'work_sessions',
      where: "status IN ('RUNNING','PAUSED')",
    );
    for (final a in active) {
      await _pauseOrInterrupt(db, a, now, interrupt: true);
    }

    if (plannedMinutes == null && taskId != null) {
      final t = await db.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1);
      if (t.isNotEmpty) {
        plannedMinutes = t.first['estimated_minutes'] as int?;
        final ss = t.first['scheduled_start'] as int?;
        final se = t.first['scheduled_end'] as int?;
        if (plannedMinutes == null && ss != null && se != null) {
          plannedMinutes = ((se - ss) / 60000).round();
        }
      }
    }
    plannedMinutes ??= 30;

    final id = AppDatabase.newId();
    await db.insert('work_sessions', {
      'id': id,
      'owner_id': ownerId,
      'task_id': taskId,
      'time_block_id': timeBlockId,
      'status': 'RUNNING',
      'planned_minutes': plannedMinutes,
      'planned_start': now,
      'started_at': now,
      'accumulated_ms': 0,
      'interrupt_count': 0,
      'created_at': now,
      'updated_at': now,
    });

    if (taskId != null) {
      await db.update(
        'tasks',
        {'status': EntityStatus.inProgress, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
    }

    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'WORK_STARTED',
      'entity_type': 'WORK_SESSION',
      'entity_id': id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': taskId != null ? '{"taskId":"$taskId"}' : null,
    });

    final row = (await db.query('work_sessions', where: 'id = ?', whereArgs: [id], limit: 1)).first;
    return WorkSession.fromMap(row);
  }

  Future<void> pause(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('work_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (rows.isEmpty) return;
    final s = rows.first;
    if (dbStr(s['status']) != 'RUNNING') return;
    final now = AppDatabase.nowMs();
    final started = dbIntOr(s['started_at']);
    final acc = dbIntOr(s['accumulated_ms']) + (now - started);
    await db.update(
      'work_sessions',
      {
        'status': 'PAUSED',
        'paused_at': now,
        'accumulated_ms': acc,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    await _event('WORK_PAUSED', sessionId, now);
  }

  Future<void> resume(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('work_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (rows.isEmpty) return;
    final s = rows.first;
    if (dbStr(s['status']) != 'PAUSED') return;
    final now = AppDatabase.nowMs();
    // New run segment: started_at = now, keep accumulated_ms
    await db.update(
      'work_sessions',
      {
        'status': 'RUNNING',
        'started_at': now,
        'paused_at': null,
        'interrupt_count': dbIntOr(s['interrupt_count']) + 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    await _event('WORK_RESUMED', sessionId, now);
  }

  /// Complete session; records actual duration. Optionally complete the task.
  Future<WorkSession> complete(
    String sessionId, {
    bool completeTask = false,
    String? note,
  }) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final rows = await db.query('work_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (rows.isEmpty) {
      throw StateError('Session not found');
    }
    final s = rows.first;
    final now = AppDatabase.nowMs();
    var acc = dbIntOr(s['accumulated_ms']);
    if (dbStr(s['status']) == 'RUNNING') {
      acc += now - dbIntOr(s['started_at']);
    }

    await db.update(
      'work_sessions',
      {
        'status': 'COMPLETED',
        'ended_at': now,
        'paused_at': null,
        'accumulated_ms': acc,
        if (note != null) 'note': note,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    final taskId = dbStrOrNull(s['task_id']);
    final actualMin = (acc / 60000).round();
    final planned = s['planned_minutes'] as int?;

    // Stamp time_block if linked
    final blockId = dbStrOrNull(s['time_block_id']);
    if (blockId != null) {
      try {
        await db.update(
          'time_blocks',
          {
            'status': 'COMPLETED',
            'actual_minutes': actualMin,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [blockId],
        );
      } catch (_) {}
    }

    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'WORK_COMPLETED',
      'entity_type': 'WORK_SESSION',
      'entity_id': sessionId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata':
          '{"actualMinutes":$actualMin,"plannedMinutes":${planned ?? 'null'},"taskId":"${taskId ?? ''}"}',
    });

    if (completeTask && taskId != null) {
      await TaskRepository(_db).complete(taskId);
    }

    final row = (await db.query('work_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1)).first;
    return WorkSession.fromMap(row);
  }

  Future<void> cancel(String sessionId) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final rows = await db.query('work_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (rows.isEmpty) return;
    final s = rows.first;
    var acc = dbIntOr(s['accumulated_ms']);
    if (dbStr(s['status']) == 'RUNNING') {
      acc += now - dbIntOr(s['started_at']);
    }
    await db.update(
      'work_sessions',
      {
        'status': 'CANCELLED',
        'ended_at': now,
        'accumulated_ms': acc,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    await _event('WORK_CANCELLED', sessionId, now);
  }

  Future<void> _pauseOrInterrupt(
    dynamic db,
    Map<String, Object?> s,
    int now, {
    required bool interrupt,
  }) async {
    var acc = dbIntOr(s['accumulated_ms']);
    if (dbStr(s['status']) == 'RUNNING') {
      acc += now - dbIntOr(s['started_at']);
    }
    await db.update(
      'work_sessions',
      {
        'status': interrupt ? 'INTERRUPTED' : 'PAUSED',
        'ended_at': interrupt ? now : null,
        'paused_at': interrupt ? null : now,
        'accumulated_ms': acc,
        'interrupt_count': dbIntOr(s['interrupt_count']) + (interrupt ? 1 : 0),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [s['id']],
    );
  }

  Future<void> _event(String type, String sessionId, int now) async {
    final ownerId = await _db.requireOwnerId();
    await (await _db.database).insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': type,
      'entity_type': 'WORK_SESSION',
      'entity_id': sessionId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
  }

  /// Personal intelligence: how estimates compare to actuals for this task / similar titles.
  Future<EstimateInsight> insightForTask(String taskId) async {
    final db = await _db.database;
    final rows = await db.query(
      'work_sessions',
      where: "task_id = ? AND status = 'COMPLETED' AND accumulated_ms > 0",
      whereArgs: [taskId],
    );
    if (rows.isEmpty) {
      // fallback: same project tasks
      final task = await db.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1);
      final projectId = task.isEmpty ? null : task.first['project_id'] as String?;
      if (projectId != null) {
        final sibs = await db.rawQuery('''
          SELECT w.* FROM work_sessions w
          JOIN tasks t ON t.id = w.task_id
          WHERE t.project_id = ? AND w.status = 'COMPLETED' AND w.accumulated_ms > 0
          ORDER BY w.ended_at DESC LIMIT 15
        ''', [projectId]);
        return _insightFromRows(sibs);
      }
      return const EstimateInsight(
        sampleCount: 0,
        avgActualMinutes: 0,
        avgPlannedMinutes: 0,
        ratio: 1,
      );
    }
    return _insightFromRows(rows);
  }

  EstimateInsight _insightFromRows(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const EstimateInsight(
          sampleCount: 0, avgActualMinutes: 0, avgPlannedMinutes: 0, ratio: 1);
    }
    var actualSum = 0.0;
    var plannedSum = 0.0;
    var plannedN = 0;
    for (final r in rows) {
      actualSum += dbIntOr(r['accumulated_ms']) / 60000.0;
      final p = r['planned_minutes'] as int?;
      if (p != null && p > 0) {
        plannedSum += p;
        plannedN++;
      }
    }
    final avgA = actualSum / rows.length;
    final avgP = plannedN == 0 ? avgA : plannedSum / plannedN;
    final ratio = avgP <= 0 ? 1.0 : avgA / avgP;
    return EstimateInsight(
      sampleCount: rows.length,
      avgActualMinutes: avgA,
      avgPlannedMinutes: avgP,
      ratio: ratio,
    );
  }
}
