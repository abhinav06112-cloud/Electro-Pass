import 'dart:typed_data';

import 'vault_crypto.dart';

/// Derives a symmetric key from a secret, a salt and a PBKDF2 iteration count.
typedef Kdf = Future<Uint8List> Function(
    String secret, Uint8List salt, int iterations);

/// Owns the vault key (VK) and its wrapped copies.
///
/// The VK is random and never persisted in the clear. On this device it is
/// sealed under a key derived from the PIN; in the cloud profile it is sealed
/// under the account password and, separately, under the recovery key.
/// Framework-free so it can be unit tested.
class KeyRing {
  KeyRing(this._kdf,
      {this.pinIter = 30000,
      this.accountIter = 150000,
      this.recoveryIter = 100000});

  final Kdf _kdf;
  final int pinIter, accountIter, recoveryIter;

  String? pinSalt; // base64-encoded salt for the PIN-derived key
  String? wrappedVk; // VK sealed under the PIN-derived key
  Uint8List? vk; // held in memory only while unlocked
  Uint8List? pinKey;

  bool get unlocked => vk != null;
  bool get hasPin => pinSalt != null && wrappedVk != null;

  /// Protects [newVk] with a freshly salted key derived from [pin].
  Future<void> install(String pin, Uint8List newVk) async {
    final salt = VaultCrypto.randomBytes(16);
    final key = await _kdf(pin, salt, pinIter);
    pinSalt = VaultCrypto.b64(salt);
    wrappedVk = VaultCrypto.seal(key, newVk);
    pinKey = key;
    vk = newVk;
  }

  /// Unlocks in memory only when [pin] correctly unwraps the stored VK.
  Future<bool> unlockWith(String pin) async {
    final salt = pinSalt, sealed = wrappedVk;
    if (salt == null || sealed == null) return false;
    final key = await _kdf(pin, VaultCrypto.unb64(salt), pinIter);
    try {
      final opened = VaultCrypto.open(key, sealed);
      pinKey = key;
      vk = opened;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Re-wraps the current VK under a new PIN after verifying the old one.
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await unlockWith(oldPin)) return false;
    await install(newPin, vk!);
    return true;
  }

  /// Drops in-memory keys (lock) without discarding the wrapped copy.
  void clear() {
    vk = null;
    pinKey = null;
  }

  /// Swaps in a different VK (e.g. the account's), keeping the same PIN wrap.
  void replaceVk(Uint8List newVk) {
    final key = pinKey;
    if (key != null) wrappedVk = VaultCrypto.seal(key, newVk);
    vk = newVk;
  }

  // ---------------- account / cloud profile ----------------

  /// The profile fields for a brand-new account.
  Future<Map<String, dynamic>> createAccountProfile(
      String password, Uint8List accountVk, String recoveryKey) async {
    final salt = VaultCrypto.randomBytes(16);
    final recoverySalt = VaultCrypto.randomBytes(16);
    final passwordKek = await _kdf(password, salt, accountIter);
    final recoveryKek = await _kdf(
      VaultCrypto.normalizeRecovery(recoveryKey),
      recoverySalt,
      recoveryIter,
    );
    return {
      'kdf_salt': VaultCrypto.b64(salt),
      'kdf_iter': accountIter,
      'wrapped_vk': VaultCrypto.seal(passwordKek, accountVk),
      'rec_salt': VaultCrypto.b64(recoverySalt),
      'rec_iter': recoveryIter,
      'rec_wrapped_vk': VaultCrypto.seal(recoveryKek, accountVk),
    };
  }

  /// The account VK, or null when the password does not unwrap it.
  Future<Uint8List?> openWithPassword(
      Map<String, dynamic> p, String password) async {
    try {
      final salt = VaultCrypto.unb64(p['kdf_salt'] as String);
      final iter = (p['kdf_iter'] as num?)?.toInt() ?? accountIter;
      final kek = await _kdf(password, salt, iter);
      return VaultCrypto.open(kek, p['wrapped_vk'] as String);
    } catch (_) {
      return null;
    }
  }

  /// The account VK, or null when the recovery key does not unwrap it.
  Future<Uint8List?> openWithRecovery(
      Map<String, dynamic> p, String recoveryKey) async {
    try {
      final salt = VaultCrypto.unb64(p['rec_salt'] as String);
      final iter = (p['rec_iter'] as num?)?.toInt() ?? recoveryIter;
      final kek = await _kdf(
        VaultCrypto.normalizeRecovery(recoveryKey),
        salt,
        iter,
      );
      return VaultCrypto.open(kek, p['rec_wrapped_vk'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Fresh password-wrap of [accountVk] after a reset plus recovery.
  Future<Map<String, dynamic>> rewrapForPassword(
      String password, Uint8List accountVk) async {
    final salt = VaultCrypto.randomBytes(16);
    final kek = await _kdf(password, salt, accountIter);
    return {
      'kdf_salt': VaultCrypto.b64(salt),
      'kdf_iter': accountIter,
      'wrapped_vk': VaultCrypto.seal(kek, accountVk),
    };
  }
}
