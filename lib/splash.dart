// In lib/splash.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';
import 'sign_in.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // This small delay ensures the build is complete before navigating.
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final supabaseClient = Supabase.instance.client;
    final session = supabaseClient.auth.currentSession;
    final user = supabaseClient.auth.currentUser;

    if (session != null && user != null) {
      // Extract username from user_metadata
      final String? usernameFromMeta = user.userMetadata?['username'] as String?;
      // Fallback to part of email if username is not in metadata or is empty
      final String displayName = (usernameFromMeta != null && usernameFromMeta.isNotEmpty) 
                                 ? usernameFromMeta 
                                 : (user.email?.split('@').first ?? 'User');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Home(username: displayName)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignIn()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png', // Path to your logo
          width: 300,
          height: 300,
        ),
      ),
    );
  }
}