import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Shared in-memory DB bootstrap for integration tests.
Future<AppDatabase> openTestDb() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = AppDatabase.instance;
  await db.openInMemoryForTest();
  return db;
}

Future<void> closeTestDb() async {
  await AppDatabase.instance.close();
  AppDatabase.instance.resetHandle();
}
