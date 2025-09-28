// lib/forgot_password.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_otp.dart'; // Navigate to OTP entry screen
import 'sign_in.dart';

final supabase = Supabase.instance.client; // Make sure Supabase is initialized

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResetPasswordOtp(email: email),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset instruction: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Original background color
      body: SafeArea(
        child: Stack( 
          children: [
            // Wallpaper Layer (matches sign_up.dart)
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
                    height: 400.0, 
                    width: 400.0,  
                    fit: BoxFit.contain, // Ensures aspect ratio is maintained
                  ),
                ),
              ),
            ),
            // Original Content Layer
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 200),
                      // 'circle' Text widget removed
                      // SizedBox(height: 0) after 'circle' Text also removed
                      const Text(
                        'FORGOT PASSWORD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1B2E47),
                          fontSize: 30,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Enter your email address below and we'll send you a verification code to reset your password.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF5F5F5F),
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration('Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.isEmpty || !v.contains('@')
                            ? 'Please enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF558DCA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(53),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text(
                            'Send Verification Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Color(0xFF1B2E47)),
                          children: [
                            const TextSpan(text: 'Remembered your password? '),
                            TextSpan(
                              text: 'Sign In',
                              style: const TextStyle(
                                color: Color(0xFF558DCA),
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  if (_isLoading) return;
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const SignIn()),
                                        (route) => false,
                                  );
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
      labelStyle: const TextStyle(
          color: Color(0xFF1B2E47),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Poppins'),
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
          borderSide: const BorderSide(width: 2, color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(55),
        borderSide: const BorderSide(width: 2, color: Colors.red),
      ),
    );
  }
}
