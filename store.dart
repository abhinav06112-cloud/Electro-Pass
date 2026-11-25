import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthException, OtpType, PostgrestException;

import 'autofill.dart';
import 'cloud.dart';
import 'config.dart';
import 'docs.dart';
import 'kdf.dart';
import 'keyring.dart';
import 'models.dart';
import 'paper.dart';
import 'vault_crypto.dart';

enum UnlockResult { ok, wrong, locked }

class AuthResult {
  final String? error;
  final String? recoveryKey;
  final bool needsConfirmation;

  const AuthResult({
    this.error,
    this.recoveryKey,
    this.needsConfirmation = false,
  });

  bool get ok => error == null && !needsConfirmation;
}

class Health {
  final int score;
  final int logins;
  final List<Entry> weak;
  final List<List<Entry>> reused;
  final List<Entry> old;

  const Health(this.score, this.logins, this.weak, this.reused, this.old);
}

/// Single source of truth for the vault, account session and preferences.
class Store extends ChangeNotifier {
  Store._();

  static final Store instance = Store._();
  static const version = '2.0.0';
  static const feedbackEmail = 'argonagility@gmail.com';

  final _secure = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  final KeyRing _keys = KeyRing(deriveKey, pinIter: kPinIter);

  String? _legacyHash;
  String? _legacySalt;
  bool _loadFailed = false;
  bool _adopting = false;
  int _fails = 0;
  int _lockedUntil = 0;
  DateTime? _externalUntil;
  Timer? _syncTimer;
  List<Map<String, dynamic>> _deleted = [];

  Uint8List? pendingVk;
  String? pendingConfirmationEmail;
  String? pendingConfirmationPassword;
  String? lastRecoveryKey;

  List<Entry> entries = [];
  int themeIndex = 0;
  String userName = '';
  bool onboarded = false;
  bool localOnly = false;
  int lockAfterSeconds = 0;
  bool secureScreen = true;
  bool autofillOn = true;
  bool autofillConfirm = true;
  bool autofillSystem = false;
  Draft? draft;
  bool editorOpen = false;
  VoidCallback? lockHandler;
  bool syncing = false;
  String syncStatus = '';

  Palette get palette => appPalettes[themeIndex];
  bool get unlocked => _keys.unlocked;
  bool get hasPin => _keys.hasPin || _legacyHash != null;
  int get favCount => entries.where((e) => e.favorite).length;
  int countOf(ItemType type) => entries.where((e) => e.type == type).length;
  int get weakCount =>
      entries.where((e) => e.type == ItemType.login && e.strength <= 1).length;

  bool get cloudConfigured => supabaseConfigured;
  bool get signedIn => Cloud.ready && Cloud.signedIn;
  String get accountEmail => Cloud.user?.email ?? '';

  bool get needsAuth =>
      Cloud.ready &&
      !localOnly &&
      (!signedIn || (!hasPin && pendingVk == null && _keys.vk == null));

  int get lockRemaining {
    final left = _lockedUntil - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? (left / 1000).ceil() : 0;
  }

  bool get _canSync => unlocked && Cloud.ready && Cloud.signedIn;

  void lockNow() => lockHandler?.call();

  // ------------------------------------------------------------------ startup
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await Cloud.init();
    _watchAuth();

    _keys.pinSalt = await _secure.read(key: 'v2_pin_salt');
    _keys.wrappedVk = await _secure.read(key: 'v2_vk');
    if (_keys.pinSalt == null) {
      final hash = await _secure.read(key: 'pin_hash');
      if (hash != null) {
        _legacyHash = hash;
        _legacySalt = await _secure.read(key: 'pin_salt');
      }
    }

    themeIndex =
        (_prefs.getInt('theme_idx') ?? 0).clamp(0, appPalettes.length - 1);
    userName = _prefs.getString('name') ?? '';
    onboarded = (_prefs.getBool('onboarded') ?? false) || hasPin;
    localOnly = _prefs.getBool('local_only') ?? false;
    lockAfterSeconds = _prefs.getInt('lock_after') ?? 0;
    secureScreen = _prefs.getBool('secure_screen') ?? true;
    autofillOn = _prefs.getBool('autofill') ?? true;
    autofillConfirm = _prefs.getBool('af_confirm') ?? true;
    _fails = _prefs.getInt('pin_fails') ?? 0;
    _lockedUntil = _prefs.getInt('pin_locked_until') ?? 0;

    await _prefs.remove('draft');
    AutofillBridge.setSecure(secureScreen);
    refreshAutofillSystem();
  }

  // ---------------------------------------------------------------------- PIN
  String _legacyDigest(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<UnlockResult> _failedPin() async {
    _fails++;
    if (_fails >= 5) {
      final step = math.min(_fails - 5, 5);
      _lockedUntil =
          DateTime.now().millisecondsSinceEpoch + 30000 * (1 << step);
    }
    await _prefs.setInt('pin_fails', _fails);
    await _prefs.setInt('pin_locked_until', _lockedUntil);
    return lockRemaining > 0 ? UnlockResult.locked : UnlockResult.wrong;
  }

  Future<void> _resetPinFails() async {
    _fails = 0;
    _lockedUntil = 0;
    await _prefs.setInt('pin_fails', 0);
    await _prefs.setInt('pin_locked_until', 0);
  }

  Future<void> _persistKeys() async {
    await _secure.write(key: 'v2_pin_salt', value: _keys.pinSalt);
    await _secure.write(key: 'v2_vk', value: _keys.wrappedVk);
  }

  Future<UnlockResult> unlock(String pin) async {
    if (lockRemaining > 0) return UnlockResult.locked;

    if (_legacyHash != null && _keys.pinSalt == null) {
      if (_legacyDigest(pin, _legacySalt ?? '') != _legacyHash) {
        return _failedPin();
      }
      await _upgradeLegacyVault(pin);
    } else {
      if (!await _keys.unlockWith(pin)) return _failedPin();
      await _readVault();
    }

    await _resetPinFails();
    notifyListeners();
    return UnlockResult.ok;
  }

  Future<bool> checkPin(String pin) async {
    if (lockRemaining > 0) return false;
    final ok = await _keys.unlockWith(pin);
    if (!ok) await _failedPin();
    return ok;
  }

  Future<void> createPin(String pin) async {
    await _keys.install(pin, pendingVk ?? VaultCrypto.randomBytes(32));
    pendingVk = null;
    entries = [];
    _deleted = [];
    _loadFailed = false;
    await _persistKeys();
    await _writeVault();
    notifyListeners();
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await _keys.changePin(oldPin, newPin)) return false;
    await _persistKeys();
    return true;
  }

  Future<void> _upgradeLegacyVault(String pin) async {
    var old = <Entry>[];
    final raw = await _secure.read(key: 'vault');
    if (raw != null) {
      try {
        old = (jsonDecode(raw) as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    await _keys.install(pin, pendingVk ?? VaultCrypto.randomBytes(32));
    pendingVk = null;
    entries = old;
    _deleted = [];
    _loadFailed = false;
    await _persistKeys();
    await _writeVault();

    for (final key in ['vault', 'pin_hash', 'pin_salt']) {
      await _secure.delete(key: key);
    }
    _legacyHash = null;
    _legacySalt = null;
    await _prefs.remove('draft');
  }

  void lock() {
    _keys.clear();
    entries = [];
    _deleted = [];
    draft = null;
    _syncTimer?.cancel();
    notifyListeners();
  }

  // ------------------------------------------------------------ encrypted vault
  Future<void> _readVault() async {
    entries = [];
    _deleted = [];
    _loadFailed = false;

    final key = _keys.vk;
    final blob = await _secure.read(key: 'v2_vault');
    if (key != null && blob != null) {
      try {
        final decoded = jsonDecode(VaultCrypto.openString(key, blob));
        if (decoded is Map) {
          entries = ((decoded['entries'] as List?) ?? const [])
              .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _deleted = ((decoded['deleted'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {
        _loadFailed = true;
      }
    }
    _readDraft();
  }

  Future<void> _writeVault() async {
    final key = _keys.vk;
    if (key == null || _loadFailed) return;
    final envelope = jsonEncode({
      'v': 2,
      'entries': entries.map((e) => e.toJson()).toList(),
      'deleted': _deleted,
    });
    await _secure.write(
      key: 'v2_vault',
      value: VaultCrypto.sealString(key, envelope),
    );
  }

  Entry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> upsert(Entry entry) async {
    entry.updated = DateTime.now().millisecondsSinceEpoch;
    final at = entries.indexWhere((e) => e.id == entry.id);
    if (at >= 0) {
      entries[at] = entry;
    } else {
      entries.add(entry);
    }
    _deleted.removeWhere((d) => d['id'] == entry.id);
    notifyListeners();
    await _writeVault();
    syncAutofill();
    scheduleSync();
  }

  Future<void> remove(String id) async {
    final entry = byId(id);
    entries.removeWhere((e) => e.id == id);
    _deleted.removeWhere((d) => d['id'] == id);
    _deleted.add({'id': id, 'ts': DateTime.now().millisecondsSinceEpoch});
    notifyListeners();

    if (entry != null) {
      for (final imageId in entry.images) {
        await DocStore.delete(imageId);
      }
    }
    await _writeVault();
    syncAutofill();
    scheduleSync();
  }

  Future<void> toggleFav(String id) async {
    final entry = byId(id);
    if (entry == null) return;
    entry.favorite = !entry.favorite;
    entry.updated = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _writeVault();
    scheduleSync();
  }

  Health health() {
    final logins = entries
        .where((e) => e.type == ItemType.login && e.password.isNotEmpty)
        .toList();
    final weak = logins.where((e) => e.strength <= 1).toList();

    final groups = <String, List<Entry>>{};
    for (final entry in logins) {
      groups.putIfAbsent(entry.password, () => <Entry>[]).add(entry);
    }
    final reused = groups.values.where((g) => g.length > 1).toList();

    final cutoff = DateTime.now()
        .subtract(const Duration(days: 180))
        .millisecondsSinceEpoch;
    final old = logins.where((e) => e.updated < cutoff).toList();

    var score = 100 - weak.length * 12 - old.length * 4;
    for (final group in reused) {
      score -= group.length * 8;
    }
    return Health(score.clamp(0, 100), logins.length, weak, reused, old);
  }

  // -------------------------------------------------------------------- drafts
  Future<void> saveDraft(Draft draft) async {
    this.draft = draft;
    final key = _keys.vk;
    if (key == null) return;
    await _prefs.setString(
      'draft_v2',
      VaultCrypto.sealString(key, jsonEncode(draft.toJson())),
    );
  }

  Future<void> clearDraft() async {
    draft = null;
    await _prefs.remove('draft_v2');
  }

  Future<void> discardDraft() async {
    final current = draft;
    if (current != null) {
      for (final id in current.added) {
        await DocStore.delete(id);
      }
    }
    await clearDraft();
  }

  void _readDraft() {
    draft = null;
    final blob = _prefs.getString('draft_v2');
    final key = _keys.vk;
    if (blob == null || key == null) return;
    try {
      draft = Draft.fromJson(
        jsonDecode(VaultCrypto.openString(key, blob)) as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  // ------------------------------------------------- intentional external apps
  void expectExternal([Duration max = const Duration(minutes: 3)]) {
    _externalUntil = DateTime.now().add(max);
  }

  void clearExternal() => _externalUntil = null;

  bool consumeExternal() {
    final until = _externalUntil;
    _externalUntil = null;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<T> runExternal<T>(Future<T> Function() work) async {
    expectExternal(const Duration(minutes: 10));
    try {
      return await work();
    } finally {
      Future.delayed(const Duration(seconds: 2), clearExternal);
    }
  }

  // ------------------------------------------------------------------ settings
  Future<void> setThemeIndex(int index) async {
    themeIndex = index.clamp(0, appPalettes.length - 1);
    await _prefs.setInt('theme_idx', themeIndex);
    notifyListeners();
  }

  Future<void> setName(String name) async {
    userName = name.trim();
    await _prefs.setString('name', userName);
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setLockAfter(int seconds) async {
    lockAfterSeconds = seconds;
    await _prefs.setInt('lock_after', seconds);
    notifyListeners();
  }

  Future<void> setSecureScreen(bool value) async {
    secureScreen = value;
    await _prefs.setBool('secure_screen', value);
    AutofillBridge.setSecure(value);
    notifyListeners();
  }

  // ------------------------------------------------------------------ autofill
  Future<void> syncAutofill() async {
    if (!unlocked) return;
    await AutofillBridge.sync(
      autofillOn ? entries : <Entry>[],
      confirm: autofillConfirm,
    );
  }

  Future<void> refreshAutofillSystem() async {
    final enabled = await AutofillBridge.isEnabled();
    if (enabled != autofillSystem) {
      autofillSystem = enabled;
      notifyListeners();
    }
  }

  Future<void> setAutofill(bool value) async {
    autofillOn = value;
    await _prefs.setBool('autofill', value);
    notifyListeners();
    await syncAutofill();
  }

  Future<void> setAutofillConfirm(bool value) async {
    autofillConfirm = value;
    await _prefs.setBool('af_confirm', value);
    notifyListeners();
    await syncAutofill();
  }

  Future<int> importPending() async {
    if (!unlocked) return 0;
    final pending = await AutofillBridge.takePending();
    var imported = 0;

    for (final item in pending) {
      final password = (item['password'] ?? '').toString();
      if (password.isEmpty) continue;
      final username = (item['username'] ?? '').toString();
      final url = (item['url'] ?? '').toString();
      var name = (item['name'] ?? '').toString();
      if (name.isEmpty) name = url.isEmpty ? 'Login' : url;

      final wanted = normalizeDomain(url);
      Entry? existing;
      for (final entry in entries) {
        if (entry.type != ItemType.login) continue;
        final sameSite = entry.username == username &&
            (entry.url == url ||
                (wanted.isNotEmpty && entry.domain == wanted) ||
                (entry.name.isNotEmpty &&
                    normalizeDomain(entry.name) == wanted));
        if (sameSite) {
          existing = entry;
          break;
        }
      }

      if (existing != null) {
        if (existing.password != password) {
          existing.data['password'] = password;
          await upsert(existing);
          imported++;
        }
      } else {
        await upsert(Entry(
          id: newId(),
          type: ItemType.login,
          name: name,
          data: {'username': username, 'password': password, 'url': url},
        ));
        imported++;
      }
    }
    return imported;
  }

  // ------------------------------------------------------------------- account
  void _watchAuth() {
    final client = Cloud.client;
    if (client == null) return;
    client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) return;
      notifyListeners();
      final signed = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed;
      if (signed && pendingConfirmationPassword != null && !_adopting) {
        unawaited(finishConfirmation());
      }
    });
  }

  Future<AuthResult> signUp(String email, String password) async {
    final client = Cloud.client;
    if (client == null) {
      return const AuthResult(error: 'Cloud sync is not set up in this build.');
    }
    try {
      lastRecoveryKey = null;
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: kAuthRedirect,
      );
      if (response.session == null) {
        pendingConfirmationEmail = email.trim();
        pendingConfirmationPassword = password;
        return const AuthResult(needsConfirmation: true);
      }
      pendingConfirmationEmail = null;
      pendingConfirmationPassword = null;
      return await _adoptAccount(password, '');
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (_) {
      return const AuthResult(
          error: 'Something went wrong. Check your connection.');
    }
  }

  Future<AuthResult> signIn(String email, String password,
      {String recoveryKey = ''}) async {
    final client = Cloud.client;
    if (client == null) {
      return const AuthResult(error: 'Cloud sync is not set up in this build.');
    }
    try {
      lastRecoveryKey = null;
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final result = await _adoptAccount(password, recoveryKey.trim());
      if (result.error != null) await client.auth.signOut();
      return result;
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (_) {
      return const AuthResult(
          error: 'Something went wrong. Check your connection.');
    }
  }

  Future<AuthResult> resendConfirmation(String email) async {
    final client = Cloud.client;
    if (client == null) {
      return const AuthResult(error: 'Cloud sync is not set up in this build.');
    }
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: kAuthRedirect,
      );
      return const AuthResult();
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (_) {
      return const AuthResult(
          error: 'Something went wrong. Check your connection.');
    }
  }

  Future<AuthResult> verifyEmailCode(String email, String code) async {
    final client = Cloud.client;
    if (client == null) {
      return const AuthResult(error: 'Cloud sync is not set up in this build.');
    }
    try {
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.signup,
      );
      if (response.session == null) {
        return const AuthResult(
            error: 'That code did not work. Check it and try again.');
      }
      return await finishConfirmation();
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (_) {
      return const AuthResult(
          error: 'Something went wrong. Check your connection.');
    }
  }

  Future<AuthResult> finishConfirmation() async {
    final client = Cloud.client;
    if (client == null) {
      return const AuthResult(error: 'Cloud sync is not set up in this build.');
    }
    if (client.auth.currentSession == null) {
      return const AuthResult(
          error: 'Not confirmed yet. Open the email link, then continue.');
    }
    if (_adopting) return const AuthResult();
    _adopting = true;

    final password = pendingConfirmationPassword;
    pendingConfirmationPassword = null;
    try {
      if (password == null || password.isEmpty) {
        pendingConfirmationEmail = null;
        return const AuthResult(
            error: 'Email confirmed. Sign in with your password to finish.');
      }
      final result = await _adoptAccount(password, '');
      pendingConfirmationEmail = null;
      if (result.ok) await completeAuth();
      return result;
    } catch (_) {
      return const AuthResult(
          error: 'Could not finish account setup. Please sign in again.');
    } finally {
      _adopting = false;
    }
  }

  Future<AuthResult> _adoptAccount(String password, String recovery) async {
    final client = Cloud.client!;
    final uid = client.auth.currentUser!.id;
    final row =
        await client.from('profiles').select().eq('id', uid).maybeSingle();
    final wrapped = row?['wrapped_vk'] as String?;

    if (row == null || wrapped == null) {
      final key = _keys.vk ?? pendingVk ?? VaultCrypto.randomBytes(32);
      final recoveryKey = VaultCrypto.generateRecoveryKey();
      lastRecoveryKey = recoveryKey;
      final columns =
          await _keys.createAccountProfile(password, key, recoveryKey);
      await client.from('profiles').upsert({
        'id': uid,
        'email': client.auth.currentUser?.email,
        ...columns,
      });
      await _acceptVaultKey(key);
      return AuthResult(recoveryKey: recoveryKey);
    }

    final profile = Map<String, dynamic>.from(row);
    var key = await _keys.openWithPassword(profile, password);
    if (key == null &&
        recovery.isNotEmpty &&
        profile['rec_wrapped_vk'] != null) {
      key = await _keys.openWithRecovery(profile, recovery);
      if (key != null) {
        final columns = await _keys.rewrapForPassword(password, key);
        await client.from('profiles').update(columns).eq('id', uid);
      }
    }

    if (key == null) {
      return const AuthResult(
        error: "Signed in, but this password can't unlock your encrypted "
            'vault. If you reset your password, enter your recovery key.',
      );
    }
    await _acceptVaultKey(key);
    return const AuthResult();
  }

  Future<void> _acceptVaultKey(Uint8List key) async {
    if (_keys.unlocked) {
      _keys.replaceVk(key);
      await _persistKeys();
      await _writeVault();
    } else {
      pendingVk = key;
    }
  }

  Future<void> completeAuth() async {
    localOnly = false;
    await _prefs.setBool('local_only', false);
    notifyListeners();
    scheduleSync();
  }

  Future<void> continueOffline() async {
    localOnly = true;
    await _prefs.setBool('local_only', true);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await Cloud.client?.auth.signOut();
    } catch (_) {}
    await _prefs.remove('last_pull');
    await _prefs.remove('last_push');
    localOnly = true;
    await _prefs.setBool('local_only', true);
    syncStatus = '';
    notifyListeners();
  }

  // --------------------------------------------------------------- cloud sync
  void scheduleSync() {
    if (!_canSync) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), syncNow);
  }

  Future<void> syncNow() async {
    if (!_canSync || syncing) return;
    syncing = true;
    syncStatus = 'Syncing…';
    notifyListeners();

    try {
      final client = Cloud.client!;
      final uid = client.auth.currentUser!.id;
      final key = _keys.vk!;
      final started = DateTime.now().millisecondsSinceEpoch;
      var changed = false;

      final cursor = _prefs.getString('last_pull');
      var query = client.from('vault_items').select().eq('user_id', uid);
      if (cursor != null) query = query.gte('updated_at', cursor);
      final rows = await query;

      String? newestUpdate;
      for (final row in rows) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = data['id'] as String;
        final updatedAt = data['updated_at'] as String?;
        if (updatedAt != null &&
            (newestUpdate == null || updatedAt.compareTo(newestUpdate) > 0)) {
          newestUpdate = updatedAt;
        }

        final clientUpdated = (data['client_updated'] as num?)?.toInt() ?? 0;
        final index = entries.indexWhere((e) => e.id == id);
        final local = index >= 0 ? entries[index] : null;

        if (data['deleted'] == true) {
          if (local != null && local.updated <= clientUpdated) {
            entries.removeAt(index);
            changed = true;
          }
          continue;
        }
        if (local != null && local.updated >= clientUpdated) continue;

        try {
          final decoded = jsonDecode(
            VaultCrypto.openString(key, data['payload'] as String),
          ) as Map<String, dynamic>;
          final incoming = Entry.fromJson(decoded);
          if (index >= 0) {
            entries[index] = incoming;
          } else {
            entries.add(incoming);
          }
          changed = true;
        } catch (_) {}
      }

      final lastPush = _prefs.getInt('last_push') ?? 0;
      final outgoing = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry.updated > lastPush) {
          outgoing.add({
            'user_id': uid,
            'id': entry.id,
            'payload': VaultCrypto.sealString(key, jsonEncode(entry.toJson())),
            'deleted': false,
            'client_updated': entry.updated,
          });
        }
      }
      for (final tombstone in _deleted) {
        final ts = (tombstone['ts'] as num).toInt();
        if (ts > lastPush) {
          outgoing.add({
            'user_id': uid,
            'id': tombstone['id'],
            'payload': '',
            'deleted': true,
            'client_updated': ts,
          });
        }
      }
      if (outgoing.isNotEmpty) {
        await client
            .from('vault_items')
            .upsert(outgoing, onConflict: 'user_id,id');
      }

      await _prefs.setInt('last_push', started);
      if (newestUpdate != null) {
        await _prefs.setString('last_pull', newestUpdate);
      }
      final monthAgo = started - const Duration(days: 30).inMilliseconds;
      _deleted.removeWhere((d) => (d['ts'] as num).toInt() < monthAgo);

      if (changed) {
        await _writeVault();
        syncAutofill();
      }
      syncStatus = 'Synced just now';
    } on PostgrestException catch (e) {
      syncStatus = 'Cloud error: ${e.message}';
    } catch (_) {
      syncStatus = 'Offline. Will retry.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------- erase
  Future<void> eraseAll() async {
    _syncTimer?.cancel();
    await DocStore.deleteAll();
    await AutofillBridge.sync(<Entry>[], confirm: true);
    try {
      await Cloud.client?.auth.signOut();
    } catch (_) {}

    await _secure.deleteAll();
    for (final key in [
      'draft_v2',
      'last_pull',
      'last_push',
      'local_only',
      'pin_fails',
      'pin_locked_until',
    ]) {
      await _prefs.remove(key);
    }
    await _prefs.setBool('autofill', true);

    autofillOn = true;
    localOnly = false;
    _fails = 0;
    _lockedUntil = 0;
    _keys.pinSalt = null;
    _keys.wrappedVk = null;
    _keys.clear();
    _legacyHash = null;
    _legacySalt = null;
    pendingVk = null;
    entries = [];
    _deleted = [];
    draft = null;
    syncStatus = '';
    notifyListeners();
  }
}
