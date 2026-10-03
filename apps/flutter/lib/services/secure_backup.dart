import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Passphrase-protected offline backup envelope.
///
/// Format (JSON):
/// {
///   "v": 1,
///   "alg": "AES-256-CBC",
///   "salt": "...",
///   "iv": "...",
///   "ciphertext": "..."
/// }
class SecureBackup {
  static const _iterationsNote = 'SHA256(passphrase+salt) used as AES key material';

  /// Encrypt plaintext JSON backup with [passphrase].
  static String encrypt(String plaintext, String passphrase) {
    if (passphrase.length < 6) {
      throw ArgumentError('Passphrase must be at least 6 characters');\n    }
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

  /// Decrypt envelope JSON → plaintext backup JSON.
  static String decrypt(String envelopeJson, String passphrase) {
    final map = jsonDecode(envelopeJson);
    if (map is! Map) throw const FormatException('Invalid encrypted backup');
    final saltB64 = map['salt'] as String?;
    final ivB64 = map['iv'] as String?;
    final ct = map['ciphertext'] as String?;
    if (saltB64 == null || ivB64 == null || ct == null) {
      throw const FormatException('Missing salt/iv/ciphertext');
    }
    final salt = base64.decode(saltB64);
    final iv = base64.decode(ivB64);
    final key = _deriveKey(passphrase, Uint8List.fromList(salt));
    final encryptor = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    try {
      return encryptor.decrypt64(ct, iv: enc.IV(Uint8List.fromList(iv)));
    } catch (_) {
      throw const FormatException('Wrong passphrase or corrupted backup');
    }
  }

  static bool looksEncrypted(String raw) {
    try {
      final m = jsonDecode(raw);
      return m is Map && m['ciphertext'] != null && m['salt'] != null;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _deriveKey(String passphrase, List<int> salt) {
    // Lightweight KDF suitable for offline local use (not server auth).
    var material = utf8.encode(passphrase) + salt;
    Digest dig = sha256.convert(material);
    for (var i = 0; i < 10000; i++) {
      dig = sha256.convert(dig.bytes + salt);
    }
    return Uint8List.fromList(dig.bytes); // 32 bytes
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }
}
