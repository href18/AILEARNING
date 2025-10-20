import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  SupabaseManager._();

  static final SupabaseClient client = SupabaseClient(
    const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  static Future<void> initialize() async {
    if (!Supabase.instance.isInitialized) {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
      );
    }
  }
}
