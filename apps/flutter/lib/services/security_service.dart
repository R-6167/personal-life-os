import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Offline security: local PIN lock (hashed), privacy flags, wipe coordination.
class SecurityService {
  SecurityService._();
  static final instance = SecurityService._();

  static const _fileName = 'plos_security.json';

  Map<String, dynamic> _cache = {};
  bool _loaded = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        _cache = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {
      _cache = {};
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final f = await _file();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(_cache));
  }

  bool get lockEnabled => _cache['lockEnabled'] == true;

  bool get hasPin => (_cache['pinHash'] as String?)?.isNotEmpty == true;

  /// When true, app shows lock gate on cold start / resume after timeout.
  Future<void> setLockEnabled(bool enabled) async {
    await load();
    if (enabled && !hasPin) {
      throw StateError('Set a PIN before enabling lock');
    }
    _cache['lockEnabled'] = enabled;
    await _save();
  }

  Future<void> setPin(String pin) async {
    await load();
    if (pin.length < 4 || pin.length > 12) {
      throw ArgumentError('PIN must be 4–12 digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must be numeric');
    }
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    _cache['pinSalt'] = salt;
    _cache['pinHash'] = hash;
    _cache['lockEnabled'] = true;
    await _save();
  }

  Future<void> clearPin() async {
    await load();
    _cache.remove('pinSalt');
    _cache.remove('pinHash');
    _cache['lockEnabled'] = false;
    await _save();
  }

  Future<bool> verifyPin(String pin) async {
    await load();
    if (!hasPin) return true;
    final salt = _cache['pinSalt'] as String? ?? '';
    final expected = _cache['pinHash'] as String? ?? '';
    return _hashPin(pin, salt) == expected;
  }

  /// Privacy: hide amounts on Finance cards until unlocked session.
  bool get hideBalances => _cache['hideBalances'] == true;

  Future<void> setHideBalances(bool v) async {
    await load();
    _cache['hideBalances'] = v;
    await _save();
  }

  /// Auto-lock after N minutes in background (0 = only cold start).
  int get autoLockMinutes => (_cache['autoLockMinutes'] as int?) ?? 5;

  Future<void> setAutoLockMinutes(int m) async {
    await load();
    _cache['autoLockMinutes'] = m.clamp(0, 120);
    await _save();
  }

  DateTime? _lastBackground;

  void markBackground() {
    _lastBackground = DateTime.now();
  }

  /// Returns true if lock UI should show after resume.
  bool shouldLockOnResume() {
    if (!lockEnabled || !hasPin) return false;
    final mins = autoLockMinutes;
    if (mins <= 0) return false;
    final last = _lastBackground;
    if (last == null) return false;
    return DateTime.now().difference(last).inMinutes >= mins;
  }

  String _randomSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin::personal-life-os');
    return sha256.convert(bytes).toString();
  }

  /// Wipe security file (call after DB wipe).
  Future<void> wipeSecurityFile() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _cache = {};
    _loaded = true;
  }
}
