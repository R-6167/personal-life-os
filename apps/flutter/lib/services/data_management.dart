import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import 'security_service.dart';

/// Destructive data management for offline privacy.
class DataManagement {
  /// Deletes the SQLite DB and security file. App must restart / re-open DB after.
  static Future<void> wipeAllLocalData() async {
    try {
      await AppDatabase.instance.close();
    } catch (_) {}

    try {
      final dbPath = await getDatabasesPath();
      final file = File(p.join(dbPath, 'personal_life_os.db'));
      if (await file.exists()) await file.delete();
      // journal / wal
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File(p.join(dbPath, 'personal_life_os.db$suffix'));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      final dbInDocs = File(p.join(docs.path, 'personal_life_os.db'));
      if (await dbInDocs.exists()) await dbInDocs.delete();
    } catch (_) {}

    await SecurityService.instance.wipeSecurityFile();
  }
}
