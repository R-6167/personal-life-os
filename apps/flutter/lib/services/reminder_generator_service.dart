import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/goal_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import 'notification_payload.dart';

/// Create → Schedule: materialize pending reminders from life entities.
///
/// Sources:
/// tasks · bills · subscriptions · documents · appointments ·
/// habits · routines · project/goal deadlines
class ReminderGeneratorService {
  ReminderGeneratorService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Full pass: upsert auto reminders for everything due in the next [horizonDays].
  Future<int> generateAll({int horizonDays = 14}) async {
    var n = 0;
    n += await _fromTasks();
    n += await _fromBills();
    n += await _fromSubscriptions();
    n += await _fromDocuments();
    n += await _fromPractical();
    n += await _fromEvents();
    n += await _fromHabitsToday();
    n += await _fromRoutinesToday();
    n += await _fromDeadlines();
    return n;
  }

  Future<int> _fromTasks() async {
    final tasks = TaskRepository(_db);
    var n = 0;
    try {
      for (final t in await tasks.listOpen()) {
        final due = t.dueAt;
        if (due == null) continue;
        final dueDt = DateTime.fromMillisecondsSinceEpoch(due);
        // Day-of 8:00 + 1 day before 18:00
        n += await _upsert(
          sourceType: NotificationPayload.task,
          sourceId: t.id,
          title: 'Task due: ${t.title}',
          message: 'Open to complete or reschedule',
          triggerAt: DateTime(dueDt.year, dueDt.month, dueDt.day, 8),
          tag: 'due_day',
        );
        final before = DateTime(dueDt.year, dueDt.month, dueDt.day, 18)
            .subtract(const Duration(days: 1));
        if (before.isAfter(DateTime.now())) {
          n += await _upsert(
            sourceType: NotificationPayload.task,
            sourceId: t.id,
            title: 'Tomorrow: ${t.title}',
            message: 'Task due tomorrow',
            triggerAt: before,
            tag: 'due_eve',
          );
        }
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromBills() async {
    var n = 0;
    try {
      final occs = await BillRepository(_db).listOpenOccurrences();
      for (final o in occs) {
        final due = DateTime.fromMillisecondsSinceEpoch(o.dueAt);
        final name = o.billName ?? 'Bill';
        n += await _upsert(
          sourceType: NotificationPayload.billOcc,
          sourceId: o.id,
          title: 'Bill due: $name',
          message: 'Open Finance to record payment',
          triggerAt: DateTime(due.year, due.month, due.day, 9),
          tag: 'bill_due',
        );
        final eve = DateTime(due.year, due.month, due.day, 10)
            .subtract(const Duration(days: 1));
        if (eve.isAfter(DateTime.now())) {
          n += await _upsert(
            sourceType: NotificationPayload.billOcc,
            sourceId: o.id,
            title: 'Bill tomorrow: $name',
            message: 'Prepare payment',
            triggerAt: eve,
            tag: 'bill_eve',
          );
        }
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromSubscriptions() async {
    var n = 0;
    try {
      final rows = await ExtendedRepository(_db).listSubscriptions();
      for (final s in rows) {
        final renewMs = s['next_renewal_at'] as int?;
        if (renewMs == null) continue;
        final when = DateTime.fromMillisecondsSinceEpoch(renewMs);
        final name = '${s['service_name'] ?? 'Subscription'}';
        n += await _upsert(
          sourceType: NotificationPayload.subscription,
          sourceId: '${s['id']}',
          title: 'Subscription: $name',
          message: 'Renewal due — open Finance',
          triggerAt: DateTime(when.year, when.month, when.day, 9),
          tag: 'sub_renew',
        );
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromDocuments() async {
    var n = 0;
    try {
      for (final d in await ExtendedRepository(_db).listDocuments()) {
        final exp = d['expires_at'] as int?;
        if (exp == null) continue;
        final when = DateTime.fromMillisecondsSinceEpoch(exp);
        final title = '${d['title']}';
        for (final days in [30, 7, 1, 0]) {
          final t = DateTime(when.year, when.month, when.day, 9)
              .subtract(Duration(days: days));
          if (t.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) continue;
          n += await _upsert(
            sourceType: NotificationPayload.document,
            sourceId: '${d['id']}',
            title: days == 0 ? 'Expires today: $title' : 'Expires in ${days}d: $title',
            message: 'Open Practical Life',
            triggerAt: t,
            tag: 'doc_$days',
          );
        }
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromPractical() async {
    var n = 0;
    try {
      for (final p in await ExtendedRepository(_db).listPractical()) {
        final dueMs = p['due_at'] as int?;
        if (dueMs == null) continue;
        final when = DateTime.fromMillisecondsSinceEpoch(dueMs);
        final title = '${p['title']}';
        n += await _upsert(
          sourceType: NotificationPayload.practical,
          sourceId: '${p['id']}',
          title: 'Due: $title',
          message: 'Open Practical Life',
          triggerAt: DateTime(when.year, when.month, when.day, 9),
          tag: 'prac_due',
        );
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromEvents() async {
    var n = 0;
    try {
      final events = await ExtendedRepository(_db).listUpcomingAppointments(days: 14);
      for (final e in events) {
        final startMs = e['start_at'] as int?;
        if (startMs == null) continue;
        final start = DateTime.fromMillisecondsSinceEpoch(startMs);
        final title = '${e['title']}';
        // 1 hour before
        final pre = start.subtract(const Duration(hours: 1));
        if (pre.isAfter(DateTime.now())) {
          n += await _upsert(
            sourceType: NotificationPayload.event,
            sourceId: '${e['id']}',
            title: 'In 1 hour: $title',
            message: 'Appointment',
            triggerAt: pre,
            tag: 'evt_1h',
          );
        }
        // Morning of
        final morning = DateTime(start.year, start.month, start.day, 8);
        if (morning.isAfter(DateTime.now()) && morning.isBefore(start)) {
          n += await _upsert(
            sourceType: NotificationPayload.event,
            sourceId: '${e['id']}',
            title: 'Today: $title',
            message: 'On your calendar',
            triggerAt: morning,
            tag: 'evt_am',
          );
        }
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromHabitsToday() async {
    var n = 0;
    try {
      final db = await _db.database;
      final habits = await db.query('habits', where: "status = 'ACTIVE'");
      final todayStart = AppDatabase.startOfTodayMs();
      for (final h in habits) {
        final id = '${h['id']}';
        final title = '${h['title']}';
        // Prefer scheduled time if present
        var trigger = DateTime.now();
        final preferred = h['preferred_time'] as String?;
        if (preferred != null && preferred.contains(':')) {
          final parts = preferred.split(':');
          final hh = int.tryParse(parts[0]) ?? 9;
          final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          final n2 = DateTime.now();
          trigger = DateTime(n2.year, n2.month, n2.day, hh, mm);
        } else {
          final n2 = DateTime.now();
          trigger = DateTime(n2.year, n2.month, n2.day, 9);
        }
        if (trigger.isBefore(DateTime.now())) continue;
        // Skip if already completed today
        final occ = await db.query(
          'habit_occurrences',
          where: "habit_id = ? AND scheduled_date = ? AND status = 'DONE'",
          whereArgs: [id, todayStart],
          limit: 1,
        );
        if (occ.isNotEmpty) continue;
        n += await _upsert(
          sourceType: NotificationPayload.habit,
          sourceId: id,
          title: 'Habit: $title',
          message: 'Tap to log completion',
          triggerAt: trigger,
          tag: 'habit_${todayStart}',
        );
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromRoutinesToday() async {
    var n = 0;
    try {
      final db = await _db.database;
      final routines = await db.query('routines', where: "status = 'ACTIVE'");
      final todayStart = AppDatabase.startOfTodayMs();
      for (final r in routines) {
        final id = '${r['id']}';
        final name = '${r['name'] ?? r['title'] ?? 'Routine'}';
        final n2 = DateTime.now();
        final trigger = DateTime(n2.year, n2.month, n2.day, 7, 30);
        if (trigger.isBefore(DateTime.now())) continue;
        n += await _upsert(
          sourceType: NotificationPayload.routine,
          sourceId: id,
          title: 'Routine: $name',
          message: 'Start your routine',
          triggerAt: trigger,
          tag: 'routine_${todayStart}',
        );
      }
    } catch (_) {}
    return n;
  }

  Future<int> _fromDeadlines() async {
    var n = 0;
    try {
      for (final p in await ProjectRepository(_db).listActive()) {
        final td = p.targetDate;
        if (td == null) continue;
        final due = DateTime.fromMillisecondsSinceEpoch(td);
        n += await _upsert(
          sourceType: NotificationPayload.project,
          sourceId: p.id,
          title: 'Project deadline: ${p.title}',
          message: 'Check next action',
          triggerAt: DateTime(due.year, due.month, due.day, 9),
          tag: 'proj_deadline',
        );
      }
      for (final g in await GoalRepository(_db).listActive()) {
        final td = g.targetDate;
        if (td == null) continue;
        final due = DateTime.fromMillisecondsSinceEpoch(td);
        n += await _upsert(
          sourceType: NotificationPayload.goal,
          sourceId: g.id,
          title: 'Goal target: ${g.title}',
          message: 'Review progress',
          triggerAt: DateTime(due.year, due.month, due.day, 9),
          tag: 'goal_deadline',
        );
      }
    } catch (_) {}
    return n;
  }

  /// Idempotent: one PENDING reminder per source+tag.
  Future<int> _upsert({
    required String sourceType,
    required String sourceId,
    required String title,
    required String message,
    required DateTime triggerAt,
    required String tag,
  }) async {
    final now = DateTime.now();
    var when = triggerAt;
    if (when.isBefore(now.subtract(const Duration(hours: 2)))) return 0;
    if (when.isBefore(now)) when = now.add(const Duration(minutes: 3));

    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final nowMs = AppDatabase.nowMs();

    // Look for existing PENDING with same source + message tag in message prefix
    final existing = await db.query(
      'reminders',
      where: "source_type = ? AND source_id = ? AND status = 'PENDING'",
      whereArgs: [sourceType, sourceId],
    );
    for (final e in existing) {
      final msg = '${e['message'] ?? ''}';
      if (msg.startsWith('[$tag]')) {
        // Update trigger if drifted
        await db.update(
          'reminders',
          {
            'title': title,
            'message': '[$tag] $message',
            'trigger_at': when.millisecondsSinceEpoch,
            'updated_at': nowMs,
          },
          where: 'id = ?',
          whereArgs: [e['id']],
        );
        return 0;
      }
    }

    await db.insert('reminders', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'title': title,
      'message': '[$tag] $message',
      'trigger_at': when.millisecondsSinceEpoch,
      'source_type': sourceType,
      'source_id': sourceId,
      'status': 'PENDING',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    return 1;
  }

  /// Record notification outcome for history / Assistant memory.
  Future<void> recordResult({
    required String reminderId,
    required String result, // OPENED | SNOOZED | COMPLETED | DISMISSED
    int? snoozeMinutes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final meta = <String, Object?>{
      'result': result,
      if (snoozeMinutes != null) 'snoozeMinutes': snoozeMinutes,
    };
    await (await _db.database).insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'NOTIFICATION_$result',
      'entity_type': 'REMINDER',
      'entity_id': reminderId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.system,
      'metadata': meta.toString(),
    });
  }
}
