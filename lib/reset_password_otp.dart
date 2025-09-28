// lib/reset_password_otp.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password.dart';
import 'sign_in.dart';

// Ensure Supabase client is available if not passed or globally initialized elsewhere
final supabase = Supabase.instance.client;

class ResetPasswordOtp extends StatefulWidget {
  final String email;

  const ResetPasswordOtp({super.key, required this.email});

  @override
  State<ResetPasswordOtp> createState() => _ResetPasswordOtpState();
}

class _ResetPasswordOtpState extends State<ResetPasswordOtp> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final otp = _otpController.text.trim();

    try {
      print('Verifying OTP for password recovery: $otp for ${widget.email}');

      final AuthResponse res = await supabase.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.recovery,
      );

      print('OTP verification successful! Session: ${res.session != null}');
      print('User ID: ${res.user?.id}');

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ResetPassword(), 
          ),
              (route) => false,
        );
      }
    } on AuthException catch (e) {
      print('AuthException during OTP verification: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error during OTP verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // _verifyOtpSimple method removed

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      print('Resending OTP to ${widget.email}');

      await supabase.auth.signInWithOtp( // Using signInWithOtp for resend, as it's a common pattern for sending OTPs
        email: widget.email,
        // emailRedirectTo: 'io.supabase.flutter://reset-callback/', // Optional redirect
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      _otpController.clear();

    } catch (e) {
      print('Resend OTP error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack( // Added Stack for background logo
          children: [
            // Wallpaper Layer (same as sign_up.dart)
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
                      const SizedBox(height: 150), // Adjusted top spacing
                      // "circle" Text widget removed
                      // SizedBox(height: 0) after "circle" Text removed
                      const Text(
                        'VERIFY YOUR EMAIL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1B2E47),
                          fontSize: 30,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Enter the 6-digit code sent to:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF5F5F5F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF1B2E47),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _otpController,
                        decoration: _buildInputDecoration('6-Digit Code'),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 4),
                        maxLength: 6,
                        validator: (v) => v == null || v.isEmpty || v.length != 6
                            ? 'Please enter the 6-digit code'
                            : null,
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF558DCA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(53),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text(
                            'Verify Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      // "Verify (Simple Method)" button and SizedBox(height: 10) removed
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF558DCA)),
                        )
                            : const Text(
                          'Send another code',
                          style: TextStyle(
                            color: Color(0xFF558DCA),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 70),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Color(0xFF1B2E47)),
                          children: [
                            TextSpan(
                              text: 'Back to Sign In',
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
