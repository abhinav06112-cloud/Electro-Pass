import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Talks to the native Android autofill service.
///
/// Everything here quietly does nothing on web / iOS / desktop, so callers
/// never need to check the platform themselves.
class AutofillBridge {
  static const MethodChannel _ch = MethodChannel('electro/autofill');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hide the app from screenshots and the recent-apps preview.
  static Future<void> setSecure(bool on) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('setSecure', on);
    } catch (_) {}
  }

  /// Is the native part installed in this build?
  static Future<bool> ping() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('ping') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Is Electro Pass the phone's selected autofill service?
  static Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'ok', 'missing' (native code not installed) or 'unsupported'.
  static Future<String> openSettings() async {
    if (!supported) return 'unsupported';
    try {
      await _ch.invokeMethod('openSettings');
      return 'ok';
    } on MissingPluginException {
      return 'missing';
    } catch (_) {
      return 'ok';
    }
  }

  /// Push all usable logins to the native service as one JSON string.
  static Future<void> sync(List<Entry> entries, {required bool confirm}) async {
    if (!supported) return;

    final items = entries
        .where((e) => e.type == ItemType.login && e.password.isNotEmpty)
        .map((e) {
      final aliases = <String>{
        e.name,
        e.url,
        normalizeDomain(e.name),
        normalizeDomain(e.url),
      }..remove('');
      return <String, dynamic>{
        'name': e.name,
        'username': e.username,
        'password': e.password,
        'url': e.url,
        'domain': normalizeDomain(e.url),
        'aliases': aliases.toList(),
      };
    }).toList();

    try {
      await _ch.invokeMethod(
        'sync',
        jsonEncode({'confirm': confirm, 'items': items}),
      );
    } catch (_) {}
  }

  /// How many logins are waiting to be imported from Android's save prompt.
  static Future<int> pendingCount() async {
    if (!supported) return 0;
    try {
      return await _ch.invokeMethod<int>('pendingCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Logins the user chose to save from Android's "Save password?" prompt.
  static Future<List<Map<String, dynamic>>> takePending() async {
    if (!supported) return <Map<String, dynamic>>[];
    try {
      final raw = await _ch.invokeMethod<String>('takePending');
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
