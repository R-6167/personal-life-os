import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      final db = await (await exports._testDatabase()).database;
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
      expect(
        (await integrity.verifyBackupJson(jsonEncode({
          'app': 'some-other-app',
          'tasks': <Object>[],
        })).ok,
        isFalse,
      );
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
