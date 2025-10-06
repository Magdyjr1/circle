import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
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
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _invitationCodeController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final invitationCode = _invitationCodeController.text.trim();
    final email = _emailController.text.trim();
    final username = _userNameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Step 1: Validate all data with the new SQL function
      log('Validating sign up data...');
      await supabase.rpc('validate_signup_data', params: {
        'p_invitation_code': invitationCode,
        'p_user_email': email,
        'p_user_username': username,
      });
      log('Validation successful.');

      // Step 2: Create the user in auth.users (but NOT in profiles yet)
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        // NO profile data here. Profile is created AFTER OTP.
      );

      log('Auth user created successfully: ${response.user?.id}');

      if (mounted && response.user != null) {
        // Step 3: Navigate to OTP screen for verification
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              email: email,
              invitationCode: invitationCode,
              username: username,
              isSignUp: true,
            ),
          ),
        );
      } else {
        throw Exception('Sign up failed: no user was returned after sign up.');
      }
    } catch (e) {
      log('Sign up error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sign up failed: ${e.toString().split('Exception: ').last}"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -200.0,
              left: 0.0,
              right: 0.0,
              child: Opacity(
                opacity: 0.3,
                child: Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 400.0,
                    width: 400.0,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
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
                        decoration: _buildInputDecoration('Username'),
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
                        decoration: _buildInputDecoration('Email'),
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
        borderSide: const BorderSide(width: 2, color: Color(0xFF5F5F5F)),
      ),
    );
  }
}
