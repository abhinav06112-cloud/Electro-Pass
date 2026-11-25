import 'package:crypto/crypto.dart';

/// Offline TOTP (RFC 6238): HMAC-SHA1, 30-second steps, 6-digit codes.
/// Accepts the standard `otpauth://` secrets used by common authenticator
/// apps. No network access is performed.
class Totp {
  Totp._();

  static const int period = 30;
  static const int digits = 6;
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Seconds remaining before the current code expires (30 at the boundary).
  static int remaining([DateTime? now]) {
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return period - (seconds % period);
  }

  /// Fraction of the current 30-second window already elapsed (0..1).
  static double progress([DateTime? now]) {
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return (seconds % period) / period;
  }

  /// The current code, or an empty string for an unusable secret.
  static String code(String secret, [DateTime? now]) {
    final key = decode(secret);
    if (key.isEmpty) return '';

    final counter =
        (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000 ~/ period;
    // RFC 4226: the 8-byte counter is a big-endian 64-bit value.
    final message = <int>[
      for (var shift = 7; shift >= 0; shift--) (counter >> (shift * 8)) & 0xff,
    ];
    final hmac = Hmac(sha1, key).convert(message).bytes;
    final offset = hmac.last & 0x0f;
    final binary = ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    return (binary % 1000000).toString().padLeft(digits, '0');
  }

  /// Accepts a full otpauth URI or a raw base32 secret.
  static String normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';
    if (text.contains('otpauth://')) {
      final found = Uri.tryParse(text)?.queryParameters['secret'];
      if (found != null && found.isNotEmpty) text = found;
    }
    return text.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
  }

  static bool isValid(String secret) => decode(secret).isNotEmpty;

  /// RFC 4648 base32 decode, tolerant of O/0 and I/1 mix-ups and no padding.
  static List<int> decode(String raw) {
    final text = normalize(raw);
    if (text.isEmpty) return <int>[];

    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in text.split('')) {
      var value = _alphabet.indexOf(ch);
      if (value < 0) {
        if (ch == '0') {
          value = 14; // O
        } else if (ch == '1') {
          value = 8; // I
        } else {
          return <int>[];
        }
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      while (bits >= 8) {
        bytes.add((buffer >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    return bytes;
  }
}
