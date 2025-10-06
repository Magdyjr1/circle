import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'sign_in.dart';
import 'profile.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String? invitationCode;
  final String? username;
  final bool isSignUp;

  const OtpScreen({
    Key? key,
    required this.email,
    this.invitationCode,
    this.username,
    this.isSignUp = false,
  }) : super(key: key);

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final otpCode = _otpController.text.trim();
      final otpType = widget.isSignUp ? OtpType.signup : OtpType.email;

      log('Verifying OTP for ${widget.email}...');

      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: otpCode,
        type: otpType,
      );

      if (response.user != null) {
        log('OTP Verified. User is authenticated: ${response.user!.id}');
        if (widget.isSignUp) {
          log('Calling complete_user_registration...');
          await supabase.rpc('complete_user_registration', params: {
            'p_invitation_code': widget.invitationCode,
            'p_username': widget.username,
          });
          log('Registration finalized successfully.');
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(initialUsername: widget.username ?? 'User'),
            ),
            (route) => false,
          );
        }
      } else {
        throw Exception('OTP verification failed. No user was returned.');
      }
    } catch (e) {
      log('Error during OTP verification/registration: $e');
      String msg = e.toString().contains('expired')
          ? 'OTP has expired. Please request a new one.'
          : 'Invalid OTP. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(
        type: widget.isSignUp ? OtpType.signup : OtpType.email,
        email: widget.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _otpController.clear();
    } catch (e) {
      log('Resend OTP error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: Colors.red,
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
        child: Stack(
          children: [
            Positioned(
              top: 20.0,
              left: 0.0,
              right: -350.0,
              child: Opacity(
                opacity: 0.3,
                child: Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 700.0,
                    width: 700.0,
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
                      const SizedBox(height: 80),
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
                        'VERIFY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1B2E47),
                          fontSize: 36,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Enter the 6-digit code sent to',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _otpController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B2E47),
                          letterSpacing: 20,
                        ),
                        decoration: _buildInputDecoration('Verification Code', '------'),
                        validator: (value) {
                          if (value == null || value.length != 6) {
                            return 'Please enter a valid 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF558DCA),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(53)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text('Verify Code', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                        ),
                      ),
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
                                'Resend Code',
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
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Color(0xFF1B2E47)),
                          children: [
                            const TextSpan(text: "Didn't get a code? "),
                            TextSpan(
                              text: 'Back to login',
                              style: const TextStyle(
                                color: Color(0xFF558DCA),
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  if (_isLoading) return;
                                  Supabase.instance.client.auth.signOut();
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

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: const TextStyle(
        color: Color(0xFF1B2E47),
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF5F5F5F),
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 20,
      ),
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
        borderSide: const BorderSide(width: 2, color: Colors.red),
      ),
    );
  }
}
