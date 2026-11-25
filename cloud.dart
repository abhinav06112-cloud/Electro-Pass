import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// A tiny facade over Supabase so callers never touch the SDK directly.
class Cloud {
  Cloud._();

  /// Whether [init] completed successfully.
  static bool ready = false;

  /// Initializes the SDK, silently falling back to offline-only mode.
  static Future<void> init() async {
    if (!supabaseConfigured) return;
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        publishableKey: kSupabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          detectSessionInUri: true,
          detectSessionInUriPredicate: (uri) =>
              uri.scheme == 'electropass' && uri.host == 'auth-callback',
        ),
      );
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  /// Null until initialization succeeded.
  static SupabaseClient? get client => ready ? Supabase.instance.client : null;

  /// Currently authenticated user, if any.
  static User? get user => client?.auth.currentUser;

  /// Whether an active session exists.
  static bool get signedIn => client?.auth.currentSession != null;
}
