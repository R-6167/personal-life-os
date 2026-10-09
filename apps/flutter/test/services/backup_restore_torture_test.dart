import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/export_service.dart';
import 'package:ordin/services/integrity_service.dart';
import 'package:ordin/services/secure_backup.dart';

import '../helpers/test_db.dart';

void main() {
  late ExportService exports;

  setUp(() async {
    final db = await openTestDb();
    exports = ExportService(db);
  });

  tearDown(() async {
    await closeTestDb();
  });

  group('backup/restore torture tests', () {
    test('export contains metadata and every declared table', () async {
      final raw = await exports.buildBackupJson();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      expect(decoded['app'], ExportService.appTag);
      expect(decoded['schemaVersion'], greaterThan(0));
      expect(decoded['contractVersion'], greaterThan(0));
      for (final table in ExportService.tables) {
        expect(decoded[table], isA<List>(), reason: 'missing table $table');
      }

      final verification = await IntegrityService().verifyBackupJson(raw);
      expect(verification.ok, isTrue, reason: verification.summary);
    });

    test('export fails closed when any declared table cannot be read', () async {
      final db = await AppDatabase.instance.database;
      await db.execute('DROP TABLE feedback_items');

      await expectLater(
        exports.buildBackupJson(),
        throwsA(isA<StateError>()),
      );
    });

    test('malformed and unrecognized backup payloads are rejected', () async {
      final integrity = IntegrityService();
      expect((await integrity.verifyBackupJson('{broken')).ok, isFalse);
      expect((await integrity.verifyBackupJson('[]')).ok, isFalse);
      final unknownApp = await integrity.verifyBackupJson(jsonEncode({
        'app': 'some-other-app',
        'tasks': <Object>[],
      }));
      expect(unknownApp.ok, isFalse);
    });

    test('encrypted backup round-trips and rejects a wrong passphrase', () {
      const plaintext = '{"app":"ordin","tasks":[{"id":"task-1"}]}';
      final encrypted = SecureBackup.encrypt(plaintext, 'correct-horse');
      expect(SecureBackup.looksEncrypted(encrypted), isTrue);
      expect(SecureBackup.decrypt(encrypted, 'correct-horse'), plaintext);
      expect(
        () => SecureBackup.decrypt(encrypted, 'wrong-passphrase'),
        throwsA(anything),
      );
    });

    test('a failed row rolls back every row in the same restore', () async {
      final db = await AppDatabase.instance.database;
      final ownerId = await AppDatabase.instance.requireOwnerId();
      final raw = await exports.buildBackupJson();
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final now = AppDatabase.nowMs();
      payload['tasks'] = [
        {
          'id': 'stage1f-valid-task',
          'ownerId': ownerId,
          'title': 'Valid row that must roll back',
          'createdAt': now,
          'updatedAt': now,
        },
        {
          'id': 'stage1f-invalid-task',
          'ownerId': ownerId,
          'title': null,
          'createdAt': now,
          'updatedAt': now,
        },
      ];

      final result = await exports.importBackupJson(jsonEncode(payload));
      expect(result.ok, isFalse, reason: result.message);
      expect(
        await db.query('tasks', where: 'id = ?', whereArgs: ['stage1f-valid-task']),
        isEmpty,
        reason: 'a failed restore must not commit earlier rows',
      );
    });

    test('restore of an exported database is idempotent', () async {
      final raw = await exports.buildBackupJson();
      final first = await exports.importBackupJson(raw);
      final second = await exports.importBackupJson(raw);

      expect(first.ok, isTrue, reason: first.message);
      expect(second.ok, isTrue, reason: second.message);
      expect(second.total, 0, reason: second.message);
    });
  });
}
