// lib/sign_up.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'otp.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invitationCodeController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _checkingAvailability = false;
  String? _emailError;
  String? _usernameError;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _userNameController.addListener(() => _onUsernameChanged(_userNameController.text));
    _emailController.addListener(() => _onEmailChanged(_emailController.text));
  }

  @override
  void dispose() {
    _invitationCodeController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'your-secret-salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _checkAvailability() async {
    final email = _emailController.text.trim();
    final username = _userNameController.text.trim();

    if (email.isEmpty && username.isEmpty) return;
    if (_checkingAvailability) return;

    setState(() {
      _checkingAvailability = true;
      _emailError = null;
      _usernameError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final result = await supabase.rpc(
        'check_signup_availability',
        params: {'p_check_email': email, 'p_check_username': username},
      );
      if (!mounted) return;
      setState(() {
        if (result['email_available'] == false) _emailError = 'Email already registered';
        if (result['username_available'] == false) _usernameError = 'Username already taken';
      });
    } catch (e) {
      print('Availability check error: $e');
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
    }
  }

  void _onEmailChanged(String value) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && value == _emailController.text && value.length > 3 && value.contains('@')) {
        _checkAvailability();
      }
    });
  }

  void _onUsernameChanged(String value) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && value == _userNameController.text && value.length > 2) {
        _checkAvailability();
      }
    });
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_emailError != null || _usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final invitationCode = _invitationCodeController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _userNameController.text.trim();

      await supabase.rpc(
        'validate_complete_signup',
        params: {
          'p_invitation_code': invitationCode,
          'p_user_email': email,
          'p_user_username': username,
        },
      ).timeout(const Duration(seconds: 10));

      print('Validation passed - email is available');

      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password, 
        data: {
          'username': username,
          'invitation_code': invitationCode,
        },
      );

      print('User created successfully with ID: ${response.user?.id}');

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_invitation_code', invitationCode);
        await prefs.setString('pending_username', username);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => OtpScreen(
              email: email,
              invitationCode: invitationCode,
              username: username,
              isSignUp: true,
            )),
          );
        }
      } else {
         print('Sign up completed, but no user object returned from supabase.auth.signUp.');
         throw Exception('User creation failed - no user returned from signUp and no exception thrown.');
      }

    } catch (e) {
      print('Sign up error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getUserFriendlyError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getUserFriendlyError(String error) {
    if (error.contains('Invalid invitation code')) return 'Invalid invitation code.';
    if (error.contains('already been used twice')) return 'This invitation code has been used twice.';
    if (error.contains('User already registered')) {
        return 'This email is already registered. Please try logging in.';
    }
    if (error.contains('profiles_email_key') || error.contains('profile_email_unique')) {
        return 'This email is already associated with a profile.';
    }
    if (error.contains('profiles_username_key') || error.contains('profile_username_unique')) {
        return 'This username is already taken.';
    }
    if (error.contains('duplicate key value violates unique constraint')) {
        return 'This email or username is already registered.';
    }
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Keep original background color for the Scaffold itself
      body: SafeArea( 
        child: Stack( 
          children: [
            // Wallpaper Layer
            Positioned(
              top: -200.0, // Half of the logo's height (400.0 / 2)
              left: 0.0,   // Spans full width
              right: 0.0,  // Spans full width
              child: Opacity(
                opacity: 0.3,
                child: Align( // To center the image within the Positioned widget
                  alignment: Alignment.center, 
                  child: Image.asset(
                    'assets/images/logo.png', // Path to your logo
                    height: 400.0, // You can change this
                    width: 400.0,  // You can change this
                    fit: BoxFit.contain, // Ensures aspect ratio is maintained
                  ),
                ),
              ),
            ),
            // Original Content Layer
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39.0), // Changed from .0 to 39.0 for consistency
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60), // Restored top margin
                      // Foreground logo and its SizedBox removed
                      const Text(
                        'circle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF205692),
                          fontSize: 55,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 0),
                      const Text(
                        'SIGN UP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1B2E47),
                          fontSize: 36,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 30), 
                      TextFormField(
                        controller: _invitationCodeController,
                        decoration: _buildInputDecoration('Invitation Code'),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter invitation code' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _userNameController,
                        decoration: _buildInputDecoration('Username').copyWith(
                          errorText: _usernameError,
                          suffixIcon: _checkingAvailability ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF558DCA))) : null,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter username';
                          if (v.length < 3) return 'Username must be at least 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration('Email').copyWith(
                          errorText: _emailError,
                          suffixIcon: _checkingAvailability ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF558DCA))) : null,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter email';
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(v)) return 'Please enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isPasswordObscured,
                        decoration: _buildInputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF5F5F5F)),
                            onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter password';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _isConfirmPasswordObscured,
                        decoration: _buildInputDecoration('Confirm Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF5F5F5F)),
                            onPressed: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm password';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF558DCA),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(53)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text('Sign Up', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Color(0xFF1B2E47)),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Log in',
                              style: const TextStyle(color: Color(0xFF558DCA), fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () {
                                if (_isLoading) return;
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Color(0xFF558DCA)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F)), // Matched focusedErrorBorder to enabled/focused border for consistency
      ),
    );
  }
}
