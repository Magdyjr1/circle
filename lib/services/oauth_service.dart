import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:url_launcher/url_launcher.dart'; // No longer needed for manual launch

class OAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    // We will now let errors propagate to be handled by the UI layer.
    // The Supabase dashboard should be configured to disallow new sign-ups via Google
    // for this screen's intended behavior.
    debugPrint('Starting Google OAuth via Supabase SDK...');

    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      // The redirectTo parameter for the Supabase client is configured 
      // globally during Supabase.initialize or can be set in the dashboard.
      // Ensure it matches your AndroidManifest (e.g., circle://login-callback)
    );

    // If signInWithOAuth completes without error, the redirect is in progress.
    // Actual sign-in confirmation happens via the auth state listener in main.dart.
    debugPrint('Google OAuth initiated by Supabase SDK. Waiting for redirect...');
  }

  // _signInWithGoogleManual method removed as it caused redirect URI conflicts
  // and Supabase's signInWithOAuth is preferred.
}
