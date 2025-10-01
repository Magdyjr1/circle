import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SimpleAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In (OAuth flow) via SimpleAuthService...');

      // This will trigger the web-based OAuth flow managed by Supabase
      final bool success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google, // Using Supabase's enum for Google
        // The redirectTo URL must be an allowed callback URL in your Supabase project settings
        // and also configured in your Google Cloud Console "Authorized redirect URIs".
        // It should match what you've set up for deep linking if you want the app to open.
        redirectTo: 'circle://login-callback', 
      );

      if (success) {
        // For signInWithOAuth, Supabase handles the redirect and session creation.
        // The user should be signed in. You can listen to authStateChanges to confirm.
        // The `success` boolean here indicates if the redirection was initiated.
        debugPrint('Google OAuth flow initiated successfully. Waiting for redirect and Supabase to handle session.');
      } else {
        // This 'else' might not even be reachable if signInWithOAuth throws on failure.
        debugPrint('Failed to initiate Google OAuth flow.');
        throw Exception('Could not initiate Google OAuth flow.');
      }

    } catch (e) {
      debugPrint('SimpleAuthService Google Sign-In (OAuth flow) error: $e');
      rethrow;
    }
  }
}
