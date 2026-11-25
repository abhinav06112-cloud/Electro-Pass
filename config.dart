// Connection details for the Supabase project behind Electro Pass.
// The publishable (anon) key is safe to ship: row-level security plus
// on-device encryption protect the data. Never embed an "sb_secret_" key.
//
// If sign-in reports "Invalid API key", switch to the legacy anon key from
// Supabase -> Project Settings -> API Keys -> Legacy tab.
const String kSupabaseUrl = 'https://psemomzfzwioskjcuebh.supabase.co';
const String kSupabaseAnonKey =
    'sb_publishable_gefmhUGwg-1djbpG6NKf6w_ToRo8uT-';

/// Email confirmation links must return to the app, not to a web page.
/// Register this exact URL under Supabase -> Auth -> URL Configuration ->
/// Additional Redirect URLs. Disable "Confirm email" to skip that step.
const String kAuthRedirect = 'electropass://auth-callback';

/// True once the bundled endpoint and key look real (not placeholders).
bool get supabaseConfigured =>
    !kSupabaseUrl.startsWith('YOUR_') &&
    !kSupabaseAnonKey.startsWith('YOUR_') &&
    kSupabaseUrl.startsWith('http');
