class SupabaseOptions {
  /// Replace with your Supabase project URL, e.g. https://xyzcompany.supabase.co
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://your-project.supabase.co');

  /// Replace with your Supabase anon/public key (safe for client use)
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'public-anon-key');
}
