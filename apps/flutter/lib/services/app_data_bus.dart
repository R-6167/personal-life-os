import 'package:flutter/foundation.dart';

/// Domains that individual screens care about.
enum DataDomain {
  tasks,
  life,
  finance,
  today,
  timeline,
}

/// Lightweight pub/sub so mutations (assistant, forms, hubs) can tell
/// only the screens that need to refresh — not the whole HomeShell tree.
///
/// Flow:
///   Repository write → AppDataBus.notify({DataDomain.tasks})
///   Tasks tab / Today tab listeners rebuild only their slice.
class AppDataBus extends ChangeNotifier {
  AppDataBus._();
  static final instance = AppDataBus._();

  final Set<DataDomain> _dirty = {};
  int _generation = 0;

  /// Monotonically increasing; widgets can compare to skip no-op rebuilds.
  int get generation => _generation;

  /// Domains marked dirty since the last [takeDirty] (or all if never taken).
  Set<DataDomain> get dirty => Set.unmodifiable(_dirty);

  /// Mark domains dirty and notify listeners.
  void notifyDomains(Set<DataDomain> domains) {
    if (domains.isEmpty) return;
    _dirty.addAll(domains);
    _generation++;
    notifyListeners();
  }

  /// Convenience for a single domain.
  void notifyDomain(DataDomain domain) => notifyDomains({domain});

  /// Tasks (+ today summary that shows open tasks).
  void tasksChanged() => notifyDomains({DataDomain.tasks, DataDomain.today, DataDomain.timeline});

  void lifeChanged() => notifyDomains({DataDomain.life, DataDomain.today, DataDomain.timeline});

  void financeChanged() =>
      notifyDomains({DataDomain.finance, DataDomain.today, DataDomain.timeline});

  void allChanged() => notifyDomains(DataDomain.values.toSet());

  /// Consume dirty set (e.g. after a scoped reload).
  Set<DataDomain> takeDirty() {
    final out = Set<DataDomain>.from(_dirty);
    _dirty.clear();
    return out;
  }

  bool isDirty(DataDomain domain) => _dirty.contains(domain);
}
