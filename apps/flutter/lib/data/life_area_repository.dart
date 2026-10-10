import '../domain/life_area.dart';
import 'atomic_write.dart';
import 'database.dart';

/// Configurable life areas (work, health, finance, …).
class LifeAreaRepository {
  LifeAreaRepository(this._db);
  final AppDatabase _db;

  static const defaultTitles = <String>[
    'Work',
    'Learning',
    'Health',
    'Finances',
    'Relationships',
    'Home',
    'Personal growth',
    'Community',
  ];

  Future<List<LifeArea>> listActive() async {
    final ownerId = await _db.requireOwnerId();
    final rows = await (await _db.database).query(
      'life_areas',
      where: 'owner_id = ? AND archived_at IS NULL',
      whereArgs: [ownerId],
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(LifeArea.fromMap).toList();
  }

  Future<LifeArea?> getById(String id) async {
    final ownerId = await _db.requireOwnerId();
    final rows = await (await _db.database).query(
      'life_areas',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LifeArea.fromMap(rows.first);
  }

  Future<LifeArea> create({
    required String title,
    String? description,
    String? color,
    String? icon,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final clean = title.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Life area title must not be empty.');
    }
    late final int position;
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), -1) AS max_position '
          'FROM life_areas WHERE owner_id = ? AND archived_at IS NULL',
          [ownerId],
        );
        position = ((rows.first['max_position'] as int?) ?? -1) + 1;
        await txn.insert('life_areas', {
          'id': id,
          'owner_id': ownerId,
          'title': clean,
          'description': description,
          'color': color,
          'icon': icon,
          'position': position,
          'created_at': now,
          'updated_at': now,
        });
      },
      eventType: 'LIFE_AREA_CREATED',
      entityType: 'LIFE_AREA',
      entityId: id,
      occurredAt: now,
    );
    return LifeArea(
      id: id,
      ownerId: ownerId,
      title: clean,
      description: description,
      color: color,
      icon: icon,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> update({
    required String id,
    String? title,
    String? description,
    String? color,
    String? icon,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final patch = <String, Object?>{'updated_at': now};
    if (title != null) {
      final clean = title.trim();
      if (clean.isEmpty) {
        throw ArgumentError.value(title, 'title', 'Life area title must not be empty.');
      }
      patch['title'] = clean;
    }
    if (description != null) patch['description'] = description;
    if (color != null) patch['color'] = color;
    if (icon != null) patch['icon'] = icon;
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final changed = await txn.update(
          'life_areas',
          patch,
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Life area not found or not owned: $id');
        }
      },
      eventType: 'LIFE_AREA_UPDATED',
      entityType: 'LIFE_AREA',
      entityId: id,
      occurredAt: now,
    );
  }

  Future<void> archive(String id) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final changed = await txn.update(
          'life_areas',
          {'archived_at': now, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Life area not found or not owned: $id');
        }
      },
      eventType: 'LIFE_AREA_ARCHIVED',
      entityType: 'LIFE_AREA',
      entityId: id,
      occurredAt: now,
    );
  }

  Future<void> reorder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) {
      throw ArgumentError.value(orderedIds, 'orderedIds', 'Must not be empty.');
    }
    if (orderedIds.toSet().length != orderedIds.length) {
      throw ArgumentError.value(orderedIds, 'orderedIds', 'Duplicate life area ids.');
    }
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final existing = await txn.query(
          'life_areas',
          columns: ['id'],
          where: 'owner_id = ? AND archived_at IS NULL',
          whereArgs: [ownerId],
        );
        final existingIds = existing.map((r) => r['id'] as String).toSet();
        if (existingIds.length != orderedIds.length ||
            !existingIds.containsAll(orderedIds)) {
          throw StateError('orderedIds must list every active life area exactly once.');
        }
        for (var i = 0; i < orderedIds.length; i++) {
          final changed = await txn.update(
            'life_areas',
            {'position': i, 'updated_at': now},
            where: 'id = ? AND owner_id = ?',
            whereArgs: [orderedIds[i], ownerId],
          );
          if (changed != 1) {
            throw StateError('Failed to reorder life area ${orderedIds[i]}');
          }
        }
      },
      eventType: 'LIFE_AREA_REORDERED',
      entityType: 'LIFE_AREA',
      entityId: orderedIds.first,
      occurredAt: now,
    );
  }

  /// Seed default areas once for the current owner when none exist.
  Future<void> seedDefaultsIfEmpty() async {
    final existing = await listActive();
    if (existing.isNotEmpty) return;
    for (final title in defaultTitles) {
      await create(title: title);
    }
  }
}
