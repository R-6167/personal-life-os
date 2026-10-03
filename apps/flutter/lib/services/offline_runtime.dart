import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/routine_repository.dart';
import 'error_log_service.dart';
import 'integrity_service.dart';
import 'notification_service.dart';
import 'smart_reminder_service.dart';

class OfflineCapabilities {
  const OfflineCapabilities({
    required this.localDatabase,
    required this.localNotifications,
    required this.encryptedBackup,
    required this.pinLock,
    required this.noCloudAccount,
  });

  final bool localDatabase;
  final bool localNotifications;
  final bool encryptedBackup;
  final bool pinLock;
  final bool noCloudAccount;

  List<String> get lines => [
        localDatabase ? 'SQLite data on this device' : 'Database unavailable',
        localNotifications ? 'Local reminders (no server)' : 'Notifications unavailable',
        encryptedBackup ? 'Passphrase-encrypted export' : 'Backup unavailable',
        pinLock ? 'Optional PIN lock' : 'PIN lock not configured',
        noCloudAccount ? 'No cloud account required' : '—',
      ];
}

class OfflineHealth {
  OfflineHealth({
    required this.ok,
    required this.checks,
    this.lastMaintenanceAt,
  });

  final bool ok;
  final List<String> checks;
  final DateTime? lastMaintenanceAt;
}

class OfflineRuntime {
  OfflineRuntime._();
  static final instance = OfflineRuntime._();

  DateTime? lastMaintenanceAt;
  DateTime? lastSuccessfulWriteAt;
  DateTime? lastIntegrityAt;
  bool _running = false;

  bool get isOfflineFirst => true;

  OfflineCapabilities get capabilities => const OfflineCapabilities(
        localDatabase: true,
        localNotifications: true,
        encryptedBackup: true,
        pinLock: true,
        noCloudAccount: true,
      );

  void markLocalWrite() {
    lastSuccessfulWriteAt = DateTime.now();
  }

  /// Habit/routine, bills, smart practical reminders, notification schedule, integrity.
  Future<void> runMaintenance({bool force = false}) async {
    if (_running) return;
    if (!force &&
        lastMaintenanceAt != null &&
        DateTime.now().difference(lastMaintenanceAt!) < const Duration(minutes: 2)) {
      return;
    }
    _running = true;
    try {
      final db = AppDatabase.instance;
      await db.database;
      final habits = HabitRepository(db);
      final routines = RoutineRepository(db);
      final bills = BillRepository(db);
      await Future.wait([
        habits.ensureAllTodayOccurrences(),
        routines.ensureAllTodayOccurrences(),
      ]);
      await Future.wait([
        habits.markMissedBeforeToday(),
        routines.markMissedBeforeToday(),
        bills.refreshOccurrenceStatuses(),
      ]);
      try {
        await SmartReminderService(db).syncAll();
      } catch (e, st) {
        await ErrorLogService.instance.log(
          message: 'smart_reminders: $e',
          stack: '$st',
          context: 'offline_runtime',
        );
      }
      try {
        await NotificationService.instance.syncFromDatabase();
      } catch (e, st) {
        await ErrorLogService.instance.log(
          message: 'notifications_sync: $e',
          stack: '$st',
          context: 'offline_runtime',
        );
      }

      final needIntegrity = force ||
          lastIntegrityAt == null ||
          DateTime.now().difference(lastIntegrityAt!) > const Duration(minutes: 30);
      if (needIntegrity) {
        final report = await IntegrityService(db: db).run(repair: true);
        lastIntegrityAt = DateTime.now();
        if (!report.ok || report.fixed > 0) {
          await ErrorLogService.instance.log(
            message: 'Integrity: ${report.summary}',
            level: 'INTEGRITY',
          );
        }
      }

      lastMaintenanceAt = DateTime.now();
    } catch (e, st) {
      await ErrorLogService.instance.log(
        message: 'maintenance: $e',
        stack: '$st',
        context: 'offline_runtime',
      );
    } finally {
      _running = false;
    }
  }

  Future<OfflineHealth> healthCheck() async {
    final checks = <String>[];
    var ok = true;
    try {
      await AppDatabase.instance.database;
      checks.add('OK: database open');
    } catch (e) {
      ok = false;
      checks.add('FAIL: database $e');
    }
    try {
      final integrity = await IntegrityService().run(repair: false);
      checks.add(integrity.ok ? 'OK: integrity' : 'WARN: ${integrity.summary}');
      if (!integrity.ok) ok = false;
    } catch (e) {
      checks.add('WARN: integrity $e');
    }
    if (lastMaintenanceAt != null) {
      checks.add('OK: last maintenance ${lastMaintenanceAt!.toIso8601String()}');
    }
    checks.addAll(capabilities.lines.map((l) => 'CAP: $l'));
    return OfflineHealth(ok: ok, checks: checks, lastMaintenanceAt: lastMaintenanceAt);
  }
}
