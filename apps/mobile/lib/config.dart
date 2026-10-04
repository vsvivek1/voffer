/// Build-time configuration, passed with `--dart-define`.
///
/// When [supabaseUrl] and [supabasePublishableKey] are both set the app talks to
/// Supabase; otherwise it runs against in-memory demo data.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
