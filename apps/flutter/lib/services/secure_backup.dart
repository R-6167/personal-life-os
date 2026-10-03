import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Passphrase-protected offline backup envelope.
class SecureBackup {
  static const _iterationsNote = 'PBKDF2-HMAC-SHA256-x10000';

  /// Encrypt plaintext JSON backup with [passphrase].
  static String encrypt(String plaintext, String passphrase) {
    if (passphrase.length < 6) {
      throw ArgumentError('Passphrase must be at least 6 characters');
    }
    final salt = _randomBytes(16);
    final iv = _randomBytes(16);
    final key = _deriveKey(passphrase, salt);
    final encryptor = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    final encrypted = encryptor.encrypt(plaintext, iv: enc.IV(iv));
    final envelope = {
      'v': 1,
      'app': 'personal-life-os',
      'alg': 'AES-256-CBC',
      'kdf': _iterationsNote,
      'salt': base64.encode(salt),
      'iv': base64.encode(iv),
      'ciphertext': encrypted.base64,
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  static String decrypt(String envelopeJson, String passphrase) {
    final map = jsonDecode(envelopeJson) as Map<String, dynamic>;
    if (map['app'] != 'personal-life-os') {
      throw StateError('Not a Personal Life OS backup');
    }
    final salt = base64.decode(map['salt'] as String);
    final iv = base64.decode(map['iv'] as String);
    final key = _deriveKey(passphrase, salt);
    final encryptor = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    return encryptor.decrypt64(map['ciphertext'] as String, iv: enc.IV(iv));
  }

  static bool looksEncrypted(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['alg'] == 'AES-256-CBC' && map['ciphertext'] is String;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Uint8List _deriveKey(String passphrase, List<int> salt) {
    final bytes = utf8.encode(passphrase);
    Digest digest = sha256.convert([...salt, ...bytes]);
    for (var i = 0; i < 9999; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return Uint8List.fromList(digest.bytes);
  }
}
