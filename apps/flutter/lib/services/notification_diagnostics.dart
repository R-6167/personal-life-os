import '../data/database.dart';

/// Best-effort, local-only diagnostics for notification failures.
/// Logging must never break notification delivery or user actions.
class NotificationDiagnostics {
  NotificationDiagnostics._();

  static Future<void> record(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> details = const {},
  }) async {
    try {
      final database = AppDatabase.instance;
      final db = await database.database;
      String? ownerId;
      try {
        ownerId = await database.requireOwnerId();
      } catch (_) {
        // Diagnostics should still be retained if the active profile is unavailable.
      }
      final now = AppDatabase.nowMs();
      final context = <String, Object?>{
        'subsystem': 'notifications',
        'operation': operation,
        ...details,
      };
      await db.insert('error_logs', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'level': 'ERROR',
        'message': 'Notification $operation failed: $error',
        'stack': stackTrace?.toString(),
        'context': _encodeContext(context),
        'occurred_at': now,
      });
    } catch (_) {
      // Deliberately swallow logging failures to avoid recursive failure loops.
    }
  }

  static String _encodeContext(Map<String, Object?> context) {
    final entries = context.entries
        .map((entry) => '"${_escape(entry.key)}":"${_escape('${entry.value ?? ''}')}"')
        .join(',');
    return '{$entries}';
  }

  static String _escape(String value) => value
      .replaceAll(r'\\', r'\\\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}
