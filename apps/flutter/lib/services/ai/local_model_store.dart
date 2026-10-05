import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps GGUF files under app documents so paths stay readable after pickers.
class LocalModelStore {
  LocalModelStore._();
  static final instance = LocalModelStore._();

  Future<Directory> modelsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copy [sourcePath] into app storage. Returns stable path + label.
  Future<({String path, String label, int bytes})> importGguf(
    String sourcePath, {
    String? preferredName,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('Source model not found: $sourcePath');
    }
    final name = preferredName?.trim().isNotEmpty == true
        ? preferredName!.trim()
        : p.basename(sourcePath);
    final safe = name.toLowerCase().endsWith('.gguf') ? name : '$name.gguf';
    final destDir = await modelsDir();
    final destPath = p.join(destDir.path, safe);

    if (p.equals(src.path, destPath)) {
      final len = await src.length();
      return (path: destPath, label: safe, bytes: len);
    }

    final dest = File(destPath);
    if (await dest.exists()) {
      final a = await src.length();
      final b = await dest.length();
      if (a == b) {
        return (path: destPath, label: safe, bytes: b);
      }
    }

    await src.copy(destPath);
    final len = await File(destPath).length();
    return (path: destPath, label: safe, bytes: len);
  }

  Future<List<FileSystemEntity>> listImported() async {
    final dir = await modelsDir();
    final list = await dir.list().toList();
    return list
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.gguf'))
        .toList();
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
