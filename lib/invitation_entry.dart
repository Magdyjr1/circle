import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'profile.dart';

class InvitationEntry extends StatefulWidget {
  final User user;
  const InvitationEntry({Key? key, required this.user}) : super(key: key);

  @override
  State<InvitationEntry> createState() => _InvitationEntryState();
}

class _InvitationEntryState extends State<InvitationEntry> {
  final _formKey = GlobalKey<FormState>();
  final _invitationCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _invitationCodeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submitInvitation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final enteredCode = _invitationCodeController.text.trim();
    final enteredUsername = _usernameController.text.trim();

    try {
      // Step 1: Perform the same validation as the sign-up screen
      log('Validating invitation data for Google user...');
      await _supabase.rpc('validate_signup_data', params: {
        'p_invitation_code': enteredCode,
        'p_user_email': widget.user.email!,
        'p_user_username': enteredUsername,
      });
      log('Validation successful.');

      // Step 2: Call the all-in-one registration function
      log('Calling complete_user_registration for Google user...');
      await _supabase.rpc('complete_user_registration', params: {
        'p_invitation_code': enteredCode,
        'p_username': enteredUsername,
      });
      log('Registration finalized successfully.');

      // Step 3: Navigate to Profile Screen on success
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(initialUsername: enteredUsername),
          ),
          (route) => false,
        );
      }
    } on Exception catch (e) {
      log('Error during invitation submission: $e');
      if (mounted) {
        setState(() {
          final message = e.toString().contains('Exception: ')
              ? e.toString().split('Exception: ').last
              : e.toString();
          _errorMessage = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
            Positioned(
              top: 0,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E47)),
                onPressed: () async {
                  await _supabase.auth.signOut();
                },
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Welcome to Circle!',
                        style: TextStyle(
                          color: Color(0xFF205692),
                          fontSize: 28,
                          fontFamily: 'Katahdin Round',
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "You are signed in as: ${widget.user.email ?? 'N/A'}\nPlease complete your registration.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1B2E47),
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _invitationCodeController,
                        decoration: _buildInputDecoration('Invitation Code'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your invitation code.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _usernameController,
                        decoration: _buildInputDecoration('Choose a Username'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please choose a username.';
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters long.';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                            return 'Username can only contain letters, numbers, and underscores.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _submitInvitation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF558DCA),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(53),
                            ),
                          ),
                          child: const Text(
                            'Complete Signup',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontFamily: 'Poppins', fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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
