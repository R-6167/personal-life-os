import '../data/atomic_write.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../domain/enums.dart';
import 'notification_service.dart';

/// Multi-tier local reminders for Practical Life.
///
/// Example (document expiring):
///   90d → 30d → 14d → 7d → 1d → day-of
///
/// Lead times depend on kind (vehicle, warranty, renewal, household…).
/// Idempotent: re-sync replaces pending reminders for the same source.
class SmartReminderService {
  SmartReminderService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  static const sourcePractical = 'PRACTICAL';
  static const sourceDocument = 'DOCUMENT';

  /// Days-before anchors by kind. Always also schedules day-of (0).
  static List<int> leadDaysForKind(String? kind) {
    switch ((kind ?? 'OTHER').toUpperCase()) {
      case 'VEHICLE':
      case 'SERVICE':
      case 'CAR':
        return [30, 14, 7, 3, 1, 0];
      case 'WARRANTY':
        return [60, 30, 14, 7, 1, 0];
      case 'RENEWAL':
        return [30, 14, 7, 3, 1, 0];
      case 'DOCUMENT':
      case 'LICENCE':
      case 'LICENSE':
      case 'ID':
        return [90, 30, 14, 7, 1, 0];
      case 'MAINTENANCE':
        return [21, 7, 1, 0];
      case 'HOUSEHOLD':
      case 'OTHER':
      default:
        return [14, 7, 1, 0];
    }
  }

  /// Replace pending reminders for [sourceType]/[sourceId] with a smart series.
  Future<int> scheduleSeries({
    required String sourceType,
    required String sourceId,
    required String title,
    required DateTime dueOrExpiry,
    String? kind,
    String? verb, // 'due' | 'expires'
  }) async {
    final now = DateTime.now();
    final nowMs = AppDatabase.nowMs();
    final dueDay = DateTime(dueOrExpiry.year, dueOrExpiry.month, dueOrExpiry.day, 9);
    final action = verb ?? 'due';
    final leads = leadDaysForKind(kind);

    final created = await AtomicWrite.run<int>(
      db: _db,
      state: (txn) async {
        // Drop existing pending for this source so re-sync is clean.
        try {
          await txn.update(
            'reminders',
            {'status': 'CANCELLED', 'updated_at': nowMs},
            where: "source_type = ? AND source_id = ? AND status = 'PENDING'",
            whereArgs: [sourceType, sourceId],
          );
        } catch (_) {}

        var n = 0;
        for (final daysBefore in leads) {
          final trigger = dueDay.subtract(Duration(days: daysBefore));
          // Only future triggers (or up to 1 hour in the past → nudge in 2 min)
          DateTime when = trigger;
          if (when.isBefore(now.subtract(const Duration(hours: 1)))) {
            continue;
          }
          if (when.isBefore(now)) {
            when = now.add(const Duration(minutes: 2));
          }

          final message = daysBefore == 0
              ? '${title} is $action today'
              : daysBefore == 1
                  ? '${title} $action tomorrow'
                  : '${title} $action in $daysBefore days';

          await txn.insert('reminders', {
            'id': AppDatabase.newId(),
            'owner_id': await _db.requireOwnerId(),
            'title': daysBefore == 0 ? title : 'Upcoming: $title',
            'message': message,
            'trigger_at': when.millisecondsSinceEpoch,
            'source_type': sourceType,
            'source_id': sourceId,
            'status': 'PENDING',
            'created_at': nowMs,
            'updated_at': nowMs,
          });
          n++;
        }
        return n;
      },
      eventType: 'SMART_REMINDERS_SCHEDULED',
      entityType: sourceType,
      entityId: sourceId,
      source: EventSource.system,
      occurredAt: nowMs,
      metadata: '{"count":0,"kind":"${kind ?? ''}"}',
    );

    // Best-effort push into OS notification scheduler (outside txn)
    try {
      await NotificationService.instance.syncFromDatabase();
    } catch (_) {}

    return created;
  }

  Future<int> scheduleForPractical({
    required String id,
    required String title,
    String? kind,
    required DateTime dueAt,
  }) {
    return scheduleSeries(
      sourceType: sourcePractical,
      sourceId: id,
      title: title,
      dueOrExpiry: dueAt,
      kind: kind,
      verb: 'due',
    );
  }

  Future<int> scheduleForDocument({
    required String id,
    required String title,
    required DateTime expiresAt,
  }) {
    return scheduleSeries(
      sourceType: sourceDocument,
      sourceId: id,
      title: title,
      dueOrExpiry: expiresAt,
      kind: 'DOCUMENT',
      verb: 'expires',
    );
  }

  /// Scan all practical items + documents and ensure smart reminder series exist.
  Future<int> syncAll() async {
    final ext = ExtendedRepository(_db);
    var total = 0;

    for (final p in await ext.listPractical()) {
      final dueMs = p['due_at'] as int?;
      if (dueMs == null) continue;
      final id = p['id'] as String;
      final title = '${p['title']}';
      final kind = p['kind'] as String?;
      total += await scheduleForPractical(
        id: id,
        title: title,
        kind: kind,
        dueAt: DateTime.fromMillisecondsSinceEpoch(dueMs),
      );
    }

    for (final d in await ext.listDocuments()) {
      final exp = d['expires_at'] as int?;
      if (exp == null) continue;
      total += await scheduleForDocument(
        id: d['id'] as String,
        title: '${d['title']}',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp),
      );
    }

    return total;
  }

  /// Cancel pending smart reminders when an item is completed/done.
  Future<void> cancelFor({required String sourceType, required String sourceId}) async {
    final now = AppDatabase.nowMs();
    try {
      await (await _db.database).update(
        'reminders',
        {'status': 'CANCELLED', 'updated_at': now},
        where: "source_type = ? AND source_id = ? AND status = 'PENDING'",
        whereArgs: [sourceType, sourceId],
      );
    } catch (_) {}
    try {
      await NotificationService.instance.syncFromDatabase();
    } catch (_) {}
  }
}
