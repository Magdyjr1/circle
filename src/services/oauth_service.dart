// services/oauth_service.dart
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class OAuthService {
  static Future<void> signInWithGoogle() async {
    try {
      // Get OAuth URL from your backend or Supabase
      final authUrl = await _getOAuthUrl();

      // Open in-app browser
      final result = await FlutterWebAuth.authenticate(
        url: authUrl,
        callbackUrlScheme: "yourapp",
      );

      // Handle the result
      await _handleOAuthCallback(result);
    } catch (e) {
      print('OAuth Error: $e');
    }
  }

  static Future<String> _getOAuthUrl() async {
    // Implement this to get OAuth URL from Supabase
    return 'https://your-project.supabase.co/auth/v1/authorize?provider=google&redirect_to=yourapp://auth-callback';
  }

  static Future<void> _handleOAuthCallback(String url) async {
    // Extract token and complete login
    final uri = Uri.parse(url);
    final token = uri.queryParameters['access_token'];
    // Use token with Supabase
  }
}