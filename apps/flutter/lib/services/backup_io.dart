import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/export_service.dart';
import 'integrity_service.dart';
import 'secure_backup.dart';

/// Hardened offline backup read/write via system file picker + share.
class BackupIo {
  BackupIo(this._db);
  final AppDatabase _db;

  /// Soft cap — prevents accidental multi-hundred-MB imports.
  static const maxBytes = 25 * 1024 * 1024;

  Future<String> buildJson({bool encrypted = false, String? passphrase}) async {
    final plain = await ExportService(_db).buildBackupJson();
    if (!encrypted) return plain;
    if (passphrase == null || passphrase.length < 6) {
      throw ArgumentError(
        'Passphrase must be at least 6 characters',
      );
    }
    return SecureBackup.encrypt(plain, passphrase);
  }

  /// Prefer system save dialog; fall back to share sheet.
  Future<BackupIoResult> exportToFile({
    bool encrypted = false,
    String? passphrase,
  }) async {
    try {
      final json = await buildJson(encrypted: encrypted, passphrase: passphrase);
      if (!encrypted) {
        final v = await IntegrityService(db: _db).verifyBackupJson(json);
        if (!v.ok) {
          return BackupIoResult(
            ok: false,
            message: 'Export verification failed: ${v.summary}',
          );
        }
      }
      final bytes = utf8.encode(json);
      if (bytes.length > maxBytes) {
        return BackupIoResult(
          ok: false,
          message:
              'Backup too large (${_kb(bytes.length)} KB). Export fewer tables or clear logs.',
        );
      }

      final name = encrypted
          ? 'personal-life-os-backup.enc.json'
          : 'personal-life-os-backup.json';

      final saved = await FilePicker.platform.saveFile(
        dialogTitle: encrypted ? 'Save encrypted backup' : 'Save backup',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );

      if (saved != null && saved.isNotEmpty) {
        try {
          final f = File(saved);
          if (!await f.exists() || await f.length() == 0) {
            await f.writeAsString(json);
          }
        } catch (_) {
          await File(saved).writeAsString(json);
        }
        return BackupIoResult(
          ok: true,
          message:
              'Saved ${encrypted ? 'encrypted ' : ''}backup (${_kb(bytes.length)} KB)',
          path: saved,
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Personal Life OS backup',
      );
      return BackupIoResult(
        ok: true,
        message: 'Shared via system sheet (${_kb(bytes.length)} KB)',
        path: file.path,
      );
    } catch (e) {
      return BackupIoResult(ok: false, message: 'Export failed: $e');
    }
  }

  /// Pick a .json file from device storage.
  Future<BackupIoResult> importFromFile({String? passphrase}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose backup file',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return BackupIoResult(ok: false, message: 'Import cancelled');
      }
      final file = result.files.single;
      if (file.size > maxBytes) {
        return BackupIoResult(
          ok: false,
          message:
              'File too large (${_kb(file.size)} KB). Max ${_kb(maxBytes)} KB.',
        );
      }

      String raw;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        raw = utf8.decode(file.bytes!, allowMalformed: false);
      } else if (file.path != null) {
        final f = File(file.path!);
        final len = await f.length();
        if (len > maxBytes) {
          return BackupIoResult(
            ok: false,
            message: 'File too large (${_kb(len)} KB)',
          );
        }
        raw = await f.readAsString();
      } else {
        return BackupIoResult(
          ok: false,
          message: 'Could not read selected file',
        );
      }

      raw = raw.trim();
      if (raw.isEmpty) {
        return BackupIoResult(ok: false, message: 'File is empty');
      }

      if (SecureBackup.looksEncrypted(raw)) {
        if (passphrase == null || passphrase.isEmpty) {
          return BackupIoResult(
            ok: false,
            message: 'Encrypted backup — passphrase required',
            needsPassphrase: true,
            pendingRaw: raw,
          );
        }
        try {
          raw = SecureBackup.decrypt(raw, passphrase);
        } catch (e) {
          return BackupIoResult(ok: false, message: 'Decrypt failed: $e');
        }
      }

      final verify = await IntegrityService(db: _db).verifyRestoreDryRun(raw);
      if (!verify.ok) {
        return BackupIoResult(
          ok: false,
          message: 'Backup failed verification: ${verify.summary}',
        );
      }

      final imported = await ExportService(_db).importBackupJson(raw);
      try {
        final post = await IntegrityService(db: _db).run(repair: true);
        final extra = post.fixed > 0 ? ' · integrity fixed ${post.fixed}' : '';
        return BackupIoResult(
          ok: imported.ok,
          message: '${imported.message}$extra',
          inserted: imported.inserted,
          total: imported.total,
        );
      } catch (_) {
        return BackupIoResult(
          ok: imported.ok,
          message: imported.message,
          inserted: imported.inserted,
          total: imported.total,
        );
      }
    } catch (e) {
      return BackupIoResult(ok: false, message: 'Import failed: $e');
    }
  }

  Future<BackupIoResult> importEncryptedRaw(
    String encrypted,
    String passphrase,
  ) async {
    try {
      final plain = SecureBackup.decrypt(encrypted, passphrase);
      final verify = await IntegrityService(db: _db).verifyRestoreDryRun(plain);
      if (!verify.ok) {
        return BackupIoResult(
          ok: false,
          message: 'Backup failed verification: ${verify.summary}',
        );
      }
      final imported = await ExportService(_db).importBackupJson(plain);
      try {
        await IntegrityService(db: _db).run(repair: true);
      } catch (_) {}
      return BackupIoResult(
        ok: imported.ok,
        message: imported.message,
        inserted: imported.inserted,
        total: imported.total,
      );
    } catch (e) {
      return BackupIoResult(ok: false, message: 'Import failed: $e');
    }
  }

  String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);
}

class BackupIoResult {
  BackupIoResult({
    required this.ok,
    required this.message,
    this.path,
    this.inserted,
    this.total,
    this.needsPassphrase = false,
    this.pendingRaw,
  });

  final bool ok;
  final String message;
  final String? path;
  final int? inserted;
  final int? total;
  final bool needsPassphrase;
  final String? pendingRaw;
}
