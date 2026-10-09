import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Passphrase-protected offline backup envelope.
///
/// Version 2 uses AES-GCM so tampering is detected before plaintext is returned.
/// Version 1 remains readable for backups created by older app versions.
class SecureBackup {
  static const _minimumPassphraseLength = 6;
  static const _iterations = 210000;
  static const _iterationsNote = 'PBKDF2-HMAC-SHA256-x210000';

  /// Encrypt plaintext JSON backup using PBKDF2 and authenticated AES-GCM.
  static Future<String> encrypt(String plaintext, String passphrase) async {
    _validatePassphrase(passphrase);
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    final envelope = {
      'v': 2,
      'app': 'personal-life-os',
      'alg': 'AES-256-GCM',
      'kdf': _iterationsNote,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Decrypt a v2 authenticated envelope or a legacy v1 AES-CBC envelope.
  static Future<String> decrypt(String envelopeJson, String passphrase) async {
    _validatePassphrase(passphrase);
    final map = jsonDecode(envelopeJson) as Map<String, dynamic>;
    if (map['app'] != 'personal-life-os') {
      throw StateError('Not a Personal Life OS backup');
    }

    switch (map['v']) {
      case 2:
        if (map['alg'] != 'AES-256-GCM' ||
            map['kdf'] != _iterationsNote) {
          throw StateError('Unsupported encrypted backup format');
        }
        final salt = base64.decode(map['salt'] as String);
        final nonce = base64.decode(map['nonce'] as String);
        final ciphertext = base64.decode(map['ciphertext'] as String);
        final mac = base64.decode(map['mac'] as String);
        if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
          throw FormatException('Invalid encrypted backup parameters');
        }
        final key = await _deriveKey(passphrase, salt);
        final box = SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(mac),
        );
        final plaintext = await AesGcm.with256bits().decrypt(
          box,
          secretKey: key,
        );
        return utf8.decode(plaintext, allowMalformed: false);
      case 1:
        if (map['alg'] != 'AES-256-CBC' ||
            map['kdf'] != 'PBKDF2-HMAC-SHA256-x10000') {
          throw StateError('Unsupported legacy encrypted backup format');
        }
        final salt = base64.decode(map['salt'] as String);
        final iv = base64.decode(map['iv'] as String);
        if (salt.length != 16 || iv.length != 16) {
          throw FormatException('Invalid legacy encrypted backup parameters');
        }
        final key = _deriveLegacyKey(passphrase, salt);
        final decryptor =
            enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
        return decryptor.decrypt64(map['ciphertext'] as String, iv: enc.IV(iv));
      default:
        throw StateError('Unsupported encrypted backup version');
    }
  }

  static bool looksEncrypted(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final isV1 = map['v'] == 1 &&
          map['alg'] == 'AES-256-CBC' &&
          map['ciphertext'] is String;
      final isV2 = map['v'] == 2 &&
          map['alg'] == 'AES-256-GCM' &&
          map['ciphertext'] is String &&
          map['mac'] is String;
      return map['app'] == 'personal-life-os' && (isV1 || isV2);
    } catch (_) {
      return false;
    }
  }

  static void _validatePassphrase(String passphrase) {
    if (passphrase.length < _minimumPassphraseLength) {
      throw ArgumentError(
        'Passphrase must be at least $_minimumPassphraseLength characters',
      );
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  /// Retained only to decrypt backups created by the old v1 format.
  static Uint8List _deriveLegacyKey(String passphrase, List<int> salt) {
    final bytes = utf8.encode(passphrase);
    Digest digest = sha256.convert([...salt, ...bytes]);
    for (var i = 0; i < 9999; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return Uint8List.fromList(digest.bytes);
  }
}
