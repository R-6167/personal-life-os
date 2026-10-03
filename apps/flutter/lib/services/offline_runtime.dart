import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/routine_repository.dart';
import 'error_log_service.dart';

/// Describes what the app can do with zero network.
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

/// Offline-first runtime: no servers, local maintenance only.
class OfflineRuntime {
  OfflineRuntime._();
  static final instance = OfflineRuntime._();

  DateTime? lastMaintenanceAt;
  DateTime? lastSuccessfulWriteAt;
  bool _running = false;

  /// Always true for this product — there is no online mode.
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

  /// Generate today's habit/routine occurrences, refresh bill statuses.
  /// Safe to call on resume; skips if already running.
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
      await db.database; // ensure open
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
      lastMaintenanceAt = DateTime.now();
    } catch (e, st) {
      await ErrorLogService.instance.log(
        message: 'Offline maintenance failed: $e',
        stack: st.toString(),
        level: 'MAINTENANCE',
      );
    } finally {
      _running = false;
    }
  }

  Future<OfflineHealth> healthCheck() async {
    final checks = <String>[];
    var ok = true;
    try {
      final db = await AppDatabase.instance.database;
      final users = await db.query('users', limit: 1);
      checks.add(users.isEmpty ? 'WARN: no local user row' : 'OK: local user present');
      if (users.isEmpty) ok = false;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      checks.add('OK: ${tables.length} local tables');

      // Smoke-read hot tables
      for (final t in ['tasks', 'habits', 'expenses', 'activity_events']) {
        try {
          await db.query(t, limit: 1);
          checks.add('OK: $t readable');
        } catch (e) {
          checks.add('FAIL: $t — $e');
          ok = false;
        }
      }

      checks.add('OK: offline-first (no network required)');
      if (lastMaintenanceAt != null) {
        checks.add('OK: last maintenance ${lastMaintenanceAt!.toIso8601String()}');
      } else {
        checks.add('INFO: maintenance not run yet this session');
      }
    } catch (e) {
      ok = false;
      checks.add('FAIL: $e');
    }
    return OfflineHealth(
      ok: ok,
      checks: checks,
      lastMaintenanceAt: lastMaintenanceAt,
    );
  }
}
