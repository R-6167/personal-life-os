import 'db_map.dart';

/// Configurable life domain (work, health, finance, …).
/// Product language: "Life Area" — not code "functions".
class LifeArea {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? color;
  final String? icon;
  final int position;
  final int? archivedAt;
  final int createdAt;
  final int updatedAt;

  const LifeArea({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.color,
    this.icon,
    this.position = 0,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  factory LifeArea.fromMap(Map<String, Object?> m) => LifeArea(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        description: m['description'] is String ? m['description'] as String : null,
        color: m['color'] is String ? m['color'] as String : null,
        icon: m['icon'] is String ? m['icon'] as String : null,
        position: dbIntOr(m['position']),
        archivedAt: m['archived_at'] is int ? m['archived_at'] as int : null,
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'color': color,
        'icon': icon,
        'position': position,
        'archived_at': archivedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
