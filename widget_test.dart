import 'package:electro_pass/config.dart';
import 'package:electro_pass/models.dart';
import 'package:electro_pass/store.dart';
import 'package:electro_pass/totp.dart';
import 'package:electro_pass/vault_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vault model helpers', () {
    test('domain normalization handles URLs, hosts and app ids', () {
      expect(normalizeDomain('https://www.Google.com/path?x=1'), 'google.com');
      expect(normalizeDomain('instagram.com'), 'instagram.com');
      expect(normalizeDomain('com.example.app'), 'com.example.app');
    });

    test('tags and custom fields survive JSON round-trips', () {
      final entry = Entry(
        id: '1',
        type: ItemType.login,
        name: 'Example',
        data: {'username': 'a@b.c', 'password': 'secret'},
        tags: const ['work'],
        custom: const {'Recovery code': '123'},
      );
      final restored = Entry.fromJson(entry.toJson());
      expect(restored.tags, ['work']);
      expect(restored.custom['Recovery code'], '123');
      expect(restored.domain, 'example');
    });

    test('password scoring rejects blocklisted values and rewards entropy', () {
      expect(passwordStrength('password123'), 0);
      expect(isCommonPassword('PASSWORD'), isTrue);
      final strong = generatePassword(length: 24);
      expect(strong.length, 24);
      expect(passwordStrength(strong), greaterThanOrEqualTo(3));
    });

    test('passphrase generation honors the requested word count', () {
      final phrase = generatePassphrase(words: 5, addNumber: false);
      expect(phrase.split('-').length, 5);
    });
  });

  group('one-time codes', () {
    test('RFC 6238 reference vector', () {
      // Base32 of "12345678901234567890" at T = 59 seconds.
      final code = Totp.code('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          DateTime.fromMillisecondsSinceEpoch(59000));
      expect(code, '287082');
    });

    test('otpauth URIs are reduced to their secret', () {
      expect(
        Totp.normalize('otpauth://totp/X?secret=JBSWY3DPEHPK3PXP'),
        'JBSWY3DPEHPK3PXP',
      );
    });
  });

  group('authentication', () {
    test('confirmation links redirect back into the app', () {
      expect(kAuthRedirect, 'electropass://auth-callback');
    });

    test('pending confirmation is a state, not an error', () {
      const result = AuthResult(needsConfirmation: true);
      expect(result.error, isNull);
      expect(result.ok, isFalse);
    });
  });

  group('vault encryption', () {
    test('round-trips with the right key and rejects a wrong one', () {
      final key = VaultCrypto.randomBytes(32);
      final sealed = VaultCrypto.sealString(key, 'hello vault');
      expect(VaultCrypto.openString(key, sealed), 'hello vault');
      final wrongKey = VaultCrypto.randomBytes(32);
      expect(() => VaultCrypto.openString(wrongKey, sealed), throwsA(anything));
    });
  });
}
