// In lib/sign_in.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Added for SVG support
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';
import 'sign_up.dart'; 
import 'forgot_password.dart'; 
import 'dart:developer'; // For log, if you want to use it here too

final supabase = Supabase.instance.client;

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    log('Sign in attempt - Email: "$email", Password length: ${password.length}');

    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      log('✅ Sign in successful for user: ${res.user?.email}');
      
      if (mounted && res.user != null) {
        final profileResponse = await supabase
            .from('profiles')
            .select('username')
            .eq('id', res.user!.id)
            .single();
        
        final username = profileResponse['username'] as String? ?? res.user!.email?.split('@').first ?? 'User';
        log('✅ Username fetched: $username');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Home(username: username)),
        );
      }
    } on AuthException catch (e) {
      log('❌ AuthException: ${e.message}');
      log('❌ Error details: ${e.toString()}');
      
      String errorMessage = 'Sign in failed: ${e.message}';
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password. Please check your credentials.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage = 'Please verify your email address before signing in.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4), 
          ),
        );
      }
    } catch (e) {
      log('❌ General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    log('Attempting Google Sign-In with redirect: io.supabase.circle://login-callback');

    try {
      final bool success = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.circle://login-callback',
      );

      if (success) {
        log('✅ Google OAuth flow initiated successfully. Waiting for app to reopen via deep link and onAuthStateChange to fire.');
        // The onAuthStateChange listener (likely in main.dart) will handle navigation
        // once the user is redirected back to the app and the session is updated.
      } else {
        log('⚠️ Google OAuth flow could not be initiated (signInWithOAuth returned false).');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not start Google Sign-In. Please ensure you have a browser and try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      log('❌ Google Sign-In AuthException: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      log('❌ Google Sign-In General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred during Google Sign-In: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // This will set isLoading to false if the OAuth initiation failed or if an error occurred.
      // If initiation was successful, the user is redirected. If they cancel and return,
      // or if the widget rebuilds for other reasons, isLoading will be reset.
      if (mounted) {
        // Only set isLoading to false here if the oauth flow didn't initiate successfully.
        // If 'success' was true, the app is waiting for redirect and auth state change.
        // However, the existing generic finally block is usually fine.
        // For more precise control, you might only set _isLoading = false in the `else` and `catch` blocks.
        // But let's stick to the current structure which resets it generally.
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 39.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Image.asset(
                    'assets/images/logo.png', 
                    height: 120,
                  ),
                  const SizedBox(height: 0),
                  const Text('circle', style: TextStyle(color: Color(0xFF205692), fontSize: 55, fontFamily: 'Katahdin Round')),
                  const SizedBox(height: 0),
                  const Text('SIGN IN', style: TextStyle(color: Color(0xFF1B2E47), fontSize: 36, fontFamily: 'Katahdin Round')),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: _buildInputDecoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty || !v.contains('@') ? 'Please enter a valid email' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    decoration: _buildInputDecoration('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter your password' : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        if (_isLoading) return;
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPassword()));
                      },
                      child: const Text('Forgot your password?', style: TextStyle(color: Color(0xFF5F5F5F), fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 55,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF558DCA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(53)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Sign in', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Flexible(child: Divider(thickness: 1, indent: 10, endIndent: 5, color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text('or', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                      ),
                      const Flexible(child: Divider(thickness: 1, indent: 5, endIndent: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 55,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B2E47), // Text and icon color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(53),
                          side: const BorderSide(color: Color(0xFF5F5F5F), width: 1),
                        ),
                        elevation: 0,
                      ),
                      icon: SvgPicture.asset(
                        'assets/icons/google_icon.svg',
                        height: 28, // A good size for the icon within the button
                      ),
                      label: const Text(
                        'Join with Google',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Color(0xFF1B2E47)),
                      children: [
                        const TextSpan(text: 'Not part of circle? , '),
                        TextSpan(
                          text: 'Sign up',
                          style: const TextStyle(color: Color(0xFF558DCA), fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              if (_isLoading) return;
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                            },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF1B2E47), fontSize: 14, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(55), borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(55), borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(55), borderSide: const BorderSide(width: 2, color: Color(0xFF558DCA))),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(55), borderSide: const BorderSide(width: 2, color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(55), borderSide: const BorderSide(width: 2, color: Colors.red)),
    );
  }
}
