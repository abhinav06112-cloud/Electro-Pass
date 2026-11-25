import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Framework-free cryptographic primitives for the vault.
///
/// PBKDF2-HMAC-SHA256 stretches a PIN or password into a 256-bit key, and
/// AES-256-GCM both encrypts and authenticates: a wrong key or any tampering
/// makes [open] throw.
class VaultCrypto {
  VaultCrypto._();

  /// [n] cryptographically secure random bytes.
  static Uint8List randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(n, (_) => rng.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256 with a 32-byte output (a single PBKDF2 block).
  static Uint8List pbkdf2(List<int> secret, List<int> salt, int iterations) {
    final mac = Hmac(sha256, secret);
    // INT(1) big-endian block index appended to the salt.
    var u = mac.convert(<int>[...salt, 0, 0, 0, 1]).bytes;
    final block = List<int>.from(u);
    for (var round = 1; round < iterations; round++) {
      u = mac.convert(u).bytes;
      for (var i = 0; i < block.length; i++) {
        block[i] ^= u[i];
      }
    }
    return Uint8List.fromList(block);
  }

  static enc.Encrypter _aes(Uint8List key) =>
      enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));

  /// AES-256-GCM. Result = base64( random 12-byte IV || ciphertext || tag ).
  static String seal(Uint8List key, List<int> plain) {
    final iv = enc.IV.fromSecureRandom(12);
    final encrypted = _aes(key).encryptBytes(plain, iv: iv);
    return b64(<int>[...iv.bytes, ...encrypted.bytes]);
  }

  /// Reverses [seal]. Throws when the key is wrong or the blob was altered.
  static Uint8List open(Uint8List key, String blob) {
    final raw = unb64(blob);
    final iv = enc.IV(Uint8List.fromList(raw.sublist(0, 12)));
    final payload = enc.Encrypted(Uint8List.fromList(raw.sublist(12)));
    return Uint8List.fromList(_aes(key).decryptBytes(payload, iv: iv));
  }

  static String sealString(Uint8List key, String text) =>
      seal(key, utf8.encode(text));

  static String openString(Uint8List key, String blob) =>
      utf8.decode(open(key, blob));

  static String b64(List<int> bytes) => base64Encode(bytes);

  static Uint8List unb64(String text) => base64Decode(text);

  // ---- recovery key: shown once, restores access after a password reset ----

  // Ambiguous glyphs (0/O, 1/I/l) are left out on purpose.
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// 20 random characters from the alphabet, displayed as four groups of five.
  static String generateRecoveryKey() {
    final rng = Random.secure();
    final chars = List<String>.generate(
      20,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    );
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 5) {
      groups.add(chars.sublist(i, i + 5).join());
    }
    return groups.join('-');
  }

  /// Strips formatting and keeps only uppercase letters and digits.
  static String normalizeRecovery(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
