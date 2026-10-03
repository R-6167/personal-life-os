import '../data/database.dart';

/// Privacy-first analytics: counts stay on device. Never uploads.
class LocalAnalytics {
  LocalAnalytics._();
  static final instance = LocalAnalytics._();

  bool enabled = true;

  Future<void> track(String eventName, {String? screen, Map<String, Object?>? props}) async {
    if (!enabled) return;
    try {
      final db = await AppDatabase.instance.database;
      String? ownerId;
      try {
        ownerId = await AppDatabase.instance.requireOwnerId();
      } catch (_) {}
      final now = AppDatabase.nowMs();
      await db.insert('app_usage_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_name': eventName,
        'screen': screen,
        'props': props == null ? null : props.toString(),
        'occurred_at': now,
      });
    } catch (_) {
      // Analytics must never break the app
    }
  }

  Future<void> screenView(String screen) => track('screen_view', screen: screen);

  Future<Map<String, int>> countsByEvent({int days = 30}) async {
    final db = await AppDatabase.instance.database;
    final since = AppDatabase.nowMs() - Duration(days: days).inMilliseconds;
    final rows = await db.rawQuery(
      '''
      SELECT event_name, COUNT(*) AS c FROM app_usage_events
      WHERE occurred_at >= ?
      GROUP BY event_name
      ORDER BY c DESC
      ''',
      [since],
    );
    return {
      for (final r in rows) '${r['event_name']}': (r['c'] as int?) ?? 0,
    };
  }

  Future<Map<String, int>> countsByScreen({int days = 30}) async {
    final db = await AppDatabase.instance.database;
    final since = AppDatabase.nowMs() - Duration(days: days).inMilliseconds;
    final rows = await db.rawQuery(
      '''
      SELECT screen, COUNT(*) AS c FROM app_usage_events
      WHERE occurred_at >= ? AND screen IS NOT NULL
      GROUP BY screen
      ORDER BY c DESC
      ''',
      [since],
    );
    return {
      for (final r in rows) '${r['screen']}': (r['c'] as int?) ?? 0,
    };
  }

  Future<int> totalEvents({int days = 30}) async {
    final db = await AppDatabase.instance.database;
    final since = AppDatabase.nowMs() - Duration(days: days).inMilliseconds;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM app_usage_events WHERE occurred_at >= ?',
      [since],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clearOlderThan(int days) async {
    final db = await AppDatabase.instance.database;
    final before = AppDatabase.nowMs() - Duration(days: days).inMilliseconds;
    await db.delete('app_usage_events', where: 'occurred_at < ?', whereArgs: [before]);
  }
}
