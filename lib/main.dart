// In lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

import 'home.dart';
import 'splash.dart';
import 'sign_in.dart';
import 'reset_password.dart'; // Import for the screen where new password is set
import 'invitation_entry.dart'; // Added this import

// Declare supabase client globally or make it accessible where needed
late final SupabaseClient supabase;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tpcydjcpevfbchgqacvv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwY3lkamNwZXZmYmNoZ3FhY3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxOTcxMDgsImV4cCI6MjA3Mzc3MzEwOH0.5F0P6yXmdelPJc0o8LU8mj9EyEcmsfh_9yU8px-2OEM',
  );
  supabase = Supabase.instance.client; // Initialize the global client

  // Add this line to sign out on every app start for testing
  await supabase.auth.signOut();
  log('User signed out at app start for testing.');

  runApp(const MyApp());
}

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
      log('Auth event: $event, Session: ${session?.user?.id}');

      if (navigatorKey.currentState == null) {
        log("Navigator key is null on $event. Navigation will be skipped.");
        return;
      }
      
      // Ensure that navigation only happens if the navigator has a mounted context
      if (!(navigatorKey.currentState?.mounted ?? false)) {
        log("Navigator not mounted on $event. Navigation will be skipped.");
        return;
      }

      if (event == AuthChangeEvent.initialSession) { // Check for initialSession specifically
        if (session == null) { // If no session on startup, go to SignIn
             log('Initial session is null, navigating to SignIn');
            navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SignIn()),
                (route) => false,
            );
        } else {
            // If there IS an initial session, proceed with profile check etc.
            // This part of the logic might seem redundant given the signOut above,
            // but onAuthStateChange can fire multiple times.
            final user = session.user;
             try {
                final profileResponse = await supabase
                    .from('profiles')
                    .select('id, username')
                    .eq('id', user.id)
                    .maybeSingle();

                if (profileResponse != null && profileResponse['id'] != null) {
                    final username = profileResponse['username'] as String? ?? user.email?.split('@').first ?? 'User';
                    log('Existing user session detected. User ID: ${user.id}, Username: $username. Navigating to Home.');
                    navigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => Home(username: username)),
                        (route) => false,
                    );
                } else {
                    log('New user session (no profile found). User ID: ${user.id}, Email: ${user.email}. Navigating to InvitationEntry.');
                    navigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => InvitationEntry(user: user)),
                        (route) => false,
                    );
                }
            } catch (e) {
                log('Error during profile check for initial session user ${user.id}: $e. Navigating to SignIn.');
                navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SignIn()),
                    (route) => false,
                );
            }
        }
      } else if (event == AuthChangeEvent.signedIn) {
        if (session != null) {
          final user = session.user;
          try {
            final profileResponse = await supabase
                .from('profiles')
                .select('id, username')
                .eq('id', user.id)
                .maybeSingle();

            if (profileResponse != null && profileResponse['id'] != null) {
              final username = profileResponse['username'] as String? ?? user.email?.split('@').first ?? 'User';
              log('Existing user signed in. User ID: ${user.id}, Username: $username. Navigating to Home.');
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => Home(username: username)),
                (route) => false,
              );
            } else {
              log('New user signed in (no profile found). User ID: ${user.id}, Email: ${user.email}. Navigating to InvitationEntry.');
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => InvitationEntry(user: user)),
                (route) => false,
              );
            }
          } catch (e) {
            log('Error during profile check/navigation for signedIn user ${user.id}: $e. Navigating to SignIn.');
            navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SignIn()),
                (route) => false,
            );
          }
        } else {
          // This case (signedIn event but session is null) should be rare.
          log('Session is null on signedIn event, navigating to SignIn');
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignIn()),
            (route) => false,
          );
        }
      } else if (event == AuthChangeEvent.signedOut) {
        log('User signed out. Navigating to SignIn.');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignIn()),
          (route) => false,
        );
      } else if (event == AuthChangeEvent.passwordRecovery) {
        log('Password recovery event detected, navigating to ResetPassword screen.');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ResetPassword()),
          (route) => false,
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
      home: const Splash(), // Splash screen still handles initial redirection logic based on auth state
    );
  }
}
