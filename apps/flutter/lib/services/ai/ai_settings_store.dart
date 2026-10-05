import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ai_types.dart';

/// Persists AI settings on device (documents dir). Never synced.
class AiSettingsStore {
  AiSettingsStore._();
  static final instance = AiSettingsStore._();

  AiSettings _cache = AiSettings();
  bool _loaded = false;

  AiSettings get current => _cache;
  bool get isLoaded => _loaded;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'ai_settings.json'));
  }

  Future<AiSettings> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cache = AiSettings.fromJson(map.cast<String, Object?>());
      }
    } catch (_) {
      _cache = AiSettings();
    }
    _loaded = true;
    return _cache;
  }

  Future<void> save(AiSettings settings) async {
    _cache = settings;
    _loaded = true;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(settings.toJson()));
    } catch (_) {}
  }
}
