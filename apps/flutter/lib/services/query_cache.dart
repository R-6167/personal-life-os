/// Tiny in-memory cache for expensive read paths (TTL-based).
/// Not a general ORM cache — just avoids repeated same-tick work.
class QueryCache {
  QueryCache._();
  static final instance = QueryCache._();

  final Map<String, _Entry> _map = {};

  Future<T> getOrLoad<T>(
    String key,
    Future<T> Function() loader, {
    Duration ttl = const Duration(seconds: 8),
  }) async {
    final now = DateTime.now();
    final hit = _map[key];
    if (hit != null && hit.expires.isAfter(now)) {
      return hit.value as T;
    }
    final value = await loader();
    _map[key] = _Entry(value, now.add(ttl));
    return value;
  }

  void invalidate([String? prefix]) {
    if (prefix == null) {
      _map.clear();
      return;
    }
    _map.removeWhere((k, _) => k.startsWith(prefix));
  }
}

class _Entry {
  _Entry(this.value, this.expires);
  final Object? value;
  final DateTime expires;
}
