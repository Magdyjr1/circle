import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://tpcydjcpevfbchgqacvv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwY3lkamNwZXZmYmNoZ3FhY3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxOTcxMDgsImV4cCI6MjA3Mzc3MzEwOH0.5F0P6yXmdelPJc0o8LU8mj9EyEcmsfh_9yU8px-2OEM',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
