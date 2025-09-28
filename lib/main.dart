// In lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

import 'home.dart';
import 'splash.dart';
import 'sign_in.dart';
import 'reset_password.dart'; // Import for the screen where new password is set
// import 'reset_password_otp.dart'; // No longer navigated to directly from main.dart for this event

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tpcydjcpevfbchgqacvv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwY3lkamNwZXZmYmNoZ3FhY3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxOTcxMDgsImV4cCI6MjA3Mzc3MzEwOH0.5F0P6yXmdelPJc0o8LU8mj9EyEcmsfh_9yU8px-2OEM',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      log('Auth event: $event, Session: $session');

      if (navigatorKey.currentState == null) {
        log("Navigator key is null on $event. Navigation will be skipped.");
        return;
      }

      if (event == AuthChangeEvent.initialSession || event == AuthChangeEvent.signedIn) {
        if (session != null) {
          try {
            final user = session.user;
            final profileResponse = await supabase
                .from('profiles')
                .select('username')
                .eq('id', user.id)
                .single();
            
            final username = profileResponse['username'] as String? ?? user.email?.split('@').first ?? 'User';
            log('User signed in. Username: $username');

            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (context) => Home(username: username)),
            );
          } catch (e) {
            log('Error fetching profile or navigating to Home: $e');
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (context) => const SignIn()),
            );
          }
        } else {
          log('Session is null on $event, navigating to SignIn');
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (context) => const SignIn()),
          );
        }
      } else if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (context) => const SignIn()),
        );
      } else if (event == AuthChangeEvent.passwordRecovery) {
        // Direct navigation to ResetPassword screen after email link is clicked
        log('Password recovery event detected, navigating to ResetPassword screen.');
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (context) => const ResetPassword()), // Navigate to ResetPassword
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF558DCA),
          selectionColor: Color(0xFF558DCA),
          selectionHandleColor: Color(0xFF558DCA),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const Splash(),
    );
  }
}
