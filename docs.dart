import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Stores photos of documents. Every photo is AES-256-GCM encrypted.
///
/// The key lives in the OS secure storage; files live in app storage
/// (browser storage when running on web). Decrypted bytes are kept only in a
/// process-lifetime memory cache and dropped when the app locks.
class DocStore {
  DocStore._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static const String _keyName = 'doc_key';
  static const String _folderName = 'vault_docs';

  static enc.Key? _key;
  static final Map<String, Uint8List> _cache = {};

  static String _prefKey(String id) => 'doc_$id';

  /// Load (or create) the 256-bit document key and remember it for this run.
  static Future<enc.Key> _getKey() async {
    final remembered = _key;
    if (remembered != null) return remembered;

    var stored = await _secure.read(key: _keyName);
    if (stored == null) {
      final generated = enc.Key.fromSecureRandom(32);
      stored = base64Encode(generated.bytes);
      await _secure.write(key: _keyName, value: stored);
    }

    final key = enc.Key(base64Decode(stored));
    _key = key;
    return key;
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/$_folderName');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static enc.Encrypter _cipher(enc.Key key) =>
      enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

  /// Encrypt `bytes`, persist them under a fresh id and return that id.
  static Future<String> save(Uint8List bytes) async {
    final id = newId();
    final key = await _getKey();
    final iv = enc.IV.fromSecureRandom(12);
    final encrypted = _cipher(key).encryptBytes(bytes, iv: iv);

    // Wire format: 12-byte IV followed by the AES-GCM ciphertext + tag.
    final payload = Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(id), base64Encode(payload));
    } else {
      final directory = await _dir();
      await File('${directory.path}/$id.enc').writeAsBytes(payload);
    }

    _cache[id] = bytes;
    return id;
  }

  static Future<Uint8List?> load(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    try {
      Uint8List payload;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final encoded = prefs.getString(_prefKey(id));
        if (encoded == null) return null;
        payload = base64Decode(encoded);
      } else {
        final file = File('${(await _dir()).path}/$id.enc');
        if (!await file.exists()) return null;
        payload = await file.readAsBytes();
      }

      final key = await _getKey();
      final iv = enc.IV(Uint8List.fromList(payload.sublist(0, 12)));
      final plain = Uint8List.fromList(_cipher(key).decryptBytes(
        enc.Encrypted(Uint8List.fromList(payload.sublist(12))),
        iv: iv,
      ));

      _cache[id] = plain;
      return plain;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String id) async {
    _cache.remove(id);
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefKey(id));
      } else {
        final file = File('${(await _dir()).path}/$id.enc');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> deleteAll() async {
    _cache.clear();
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final keys =
            prefs.getKeys().where((k) => k.startsWith('doc_')).toList();
        for (final key in keys) {
          await prefs.remove(key);
        }
      } else {
        final directory = await _dir();
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Forget decrypted photos in memory (called when the app locks).
  static void clearCache() => _cache.clear();
}
