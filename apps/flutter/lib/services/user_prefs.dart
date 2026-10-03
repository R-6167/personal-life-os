import '../data/database.dart';
import '../domain/enums.dart';

/// Cached offline profile prefs (currency, week start, display name).
/// Always prefer [currency] over [Defaults.currency] in UI and writes.
class UserPrefs {
  UserPrefs._();
  static final instance = UserPrefs._();

  String _currency = Defaults.currency;
  int _weekStartDay = Defaults.weekStartDay;
  String _displayName = 'Me';
  bool _loaded = false;

  String get currency => _currency;
  int get weekStartDay => _weekStartDay;
  String get displayName => _displayName;
  bool get isLoaded => _loaded;

  /// Load from the single local user row. Safe to call often.
  Future<void> load() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('users', limit: 1);
      if (rows.isEmpty) {
        _currency = Defaults.currency;
        _weekStartDay = Defaults.weekStartDay;
        _displayName = 'Me';
      } else {
        final r = rows.first;
        final c = (r['currency'] as String?)?.trim();
        _currency = (c == null || c.isEmpty) ? Defaults.currency : c.toUpperCase();
        _weekStartDay = (r['week_start_day'] as int?) ?? Defaults.weekStartDay;
        _displayName = (r['display_name'] as String?) ??
            (r['name'] as String?) ??
            'Me';
      }
      _loaded = true;
    } catch (_) {
      _currency = Defaults.currency;
      _loaded = true;
    }
  }

  /// After Settings saves currency/name — keep cache in sync without full reload path.
  void applyLocal({String? currency, int? weekStartDay, String? displayName}) {
    if (currency != null && currency.trim().isNotEmpty) {
      _currency = currency.trim().toUpperCase();
    }
    if (weekStartDay != null) _weekStartDay = weekStartDay;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _displayName = displayName.trim();
    }
  }
}
