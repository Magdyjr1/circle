import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'sign_in.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String invitationCode;
  final String username;
  final String? password;
  final bool isSignUp;

  const OtpScreen({
    Key? key,
    required this.email,
    required this.invitationCode,
    required this.username,
    this.password,
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

// START of new _verifyOtp method from user (version that removes setSession)
Future<void> _verifyOtp() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  setState(() => _isLoading = true);

  try {
    final supabase = Supabase.instance.client;
    final otpCode = _otpController.text.trim();

    // Use the correct OTP type
    final OtpType otpType = widget.isSignUp ? OtpType.signup : OtpType.email;

    print('Verifying OTP: $otpCode for email: ${widget.email} with type: $otpType');

    final AuthResponse result = await supabase.auth.verifyOTP(
      email: widget.email,
      token: otpCode,
      type: otpType,
    ).timeout(const Duration(seconds: 30));

    if (result.session != null) {
      // FIXED: Session is automatically set by verifyOTP, no need for setSession
      print('OTP verified successfully. User is now authenticated. User ID: ${result.user?.id}, Session: ${result.session?.accessToken.substring(0,10)}...');

      if (widget.isSignUp) {
        await _finalizeSignup();
      } else {
        _navigateToHome();
      }
    } else {
      // This block handles cases where session might be null even if user object exists
      if (result.user != null) {
          print('OTP Verified, user object exists but session is unexpectedly null. User ID: ${result.user!.id}');
          // Proceed with signup finalization as user object exists
           if (widget.isSignUp) {
              await _finalizeSignup();
           } else {
              // This case is ambiguous for non-signup flows, might be an error.
              throw Exception('OTP verification succeeded (user exists) but no session was established for a non-signup flow.');
           }
      } else {
          throw Exception('OTP verification failed. No user or session returned.');
      }
    }
  } catch (e) {
    print('OTP verification error: $e');
    String msg = 'Invalid OTP code. Please try again.';
    if (e.toString().contains('expired') || e.toString().contains('otp_expired')) {
      msg = 'OTP code has expired. Please request a new one.';
    } else if (e.toString().contains('invalid')) {
      msg = 'Invalid OTP code. Please check and try again.';
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red)
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
// END of new _verifyOtp method

  Future<void> _finalizeSignup() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      print('Error in _finalizeSignup: Current user is null after OTP verification.');
      throw Exception('User not authenticated after OTP verification. Cannot finalize signup.');
    }

    print('Finalizing signup for user: ${currentUser.id}, email: ${widget.email}, username: ${widget.username}');

    try {
      await supabase.rpc('complete_user_registration', params: {
        'p_invitation_code': widget.invitationCode,
        'p_user_email': widget.email,
        'p_user_username': widget.username,
        'p_password_hash': _hashPassword(widget.password ?? ''),
      }).timeout(const Duration(seconds: 20));

      print('RPC complete_user_registration called successfully.');
    } catch (e) {
      print('Error in complete_user_registration RPC: $e');
      await _createProfileManually(currentUser.id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_invitation_code');
    await prefs.remove('pending_username');
    await prefs.remove('pending_email');
    await prefs.remove('pending_password');
    print('Cleared pending signup data from SharedPreferences.');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home(username: widget.username)),
            (route) => false,
      );
    }
  }

  Future<void> _createProfileManually(String userId) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('profiles').insert({
        'id': userId,
        'username': widget.username,
        'email': widget.email,
        'password_hash': _hashPassword(widget.password ?? ''),
      });
      await _updateInvitationCodeManually(userId);
      await _createNewInvitationCode(userId);
      print('Manual profile creation successful for $userId');
    } catch (e) {
      print('Manual profile creation failed: $e');
    }
  }

  Future<void> _updateInvitationCodeManually(String userId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.from('invitation_codes')
          .select('usage_count, invited_users')
          .eq('code', widget.invitationCode)
          .single();

      final currentUsage = response['usage_count'] as int;
      final currentInvitedUsers = List<String>.from(response['invited_users'] ?? [])..add(userId);

      await supabase.from('invitation_codes').update({
        'usage_count': currentUsage + 1,
        'invited_users': currentInvitedUsers
      }).eq('code', widget.invitationCode);

      print('Invitation code ${widget.invitationCode} updated for user $userId');
    } catch (e) {
      print('Error updating invitation code manually: $e');
    }
  }

  Future<void> _createNewInvitationCode(String userId) async {
    final supabase = Supabase.instance.client;
    try {
      String newCode;
      bool codeExists;
      do {
        newCode = _generateRandomCode(8);
        final checkResponse = await supabase.from('invitation_codes')
            .select('code')
            .eq('code', newCode);
        codeExists = checkResponse.isNotEmpty;
      } while (codeExists);

      await supabase.from('invitation_codes').insert({
        'code': newCode,
        'user_id': userId,
        'invited_users': []
      });

      print('New invitation code created for $userId: $newCode');
    } catch (e) {
      print('Error creating new invitation code: $e');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'your-secret-salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateRandomCode(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
        Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(
        type: widget.isSignUp ? OtpType.signup : OtpType.email,
        email: widget.email
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
      print('Resend OTP error: $e');
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

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home(username: widget.username)),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Added for consistency
      body: SafeArea( // Added SafeArea
        child: Stack( // Added Stack for wallpaper
          children: [
            // Wallpaper Layer (same as sign_up.dart and forgot_password.dart)
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
                            const TextSpan(text: 'Didn\'t get a code? '),
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
