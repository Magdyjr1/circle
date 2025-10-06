import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'profile.dart';
import 'splash.dart';
import 'sign_in.dart';
import 'reset_password.dart';
import 'invitation_entry.dart';

late final SupabaseClient supabase;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tpcydjcpevfbchgqacvv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwY3lkamNwZXZmYmNoZ3FhY3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxOTcxMDgsImV4cCI6MjA3Mzc3MzEwOH0.5F0P6yXmdelPJc0o8LU8mj9EyEcmsfh_9yU8px-2OEM',
  );
  supabase = Supabase.instance.client;

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

      final navigator = navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) {
        log("Navigator not available on $event. Navigation skipped.");
        return;
      }

      // This logic now correctly handles all sign-in and startup events.
      if (event == AuthChangeEvent.initialSession || event == AuthChangeEvent.signedIn) {
        if (session == null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignIn()), (route) => false);
          return;
        }

        final user = session.user;
        try {
          // THE NEW SOURCE OF TRUTH: Does a profile exist for this user?
          final profileResponse = await supabase
              .from('profiles')
              .select('username')
              .eq('id', user.id)
              .maybeSingle();

          if (profileResponse != null) {
            // YES, a profile exists. User is fully registered.
            final username = profileResponse['username'] as String? ?? 'User';
            log('User ${user.id} has a profile. Navigating to ProfileScreen.');
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => ProfileScreen(initialUsername: username)),
              (route) => false,
            );
          } else {
            // NO, a profile does not exist. User has not completed registration.
            log('User ${user.id} does NOT have a profile. Navigating to InvitationEntry.');
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => InvitationEntry(user: user)),
              (route) => false,
            );
          }
        } catch (e) {
          log('Error during profile check for ${user.id}: $e. Navigating to SignIn.');
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignIn()), (route) => false);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        log('User signed out. Navigating to SignIn.');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignIn()), (route) => false);
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
