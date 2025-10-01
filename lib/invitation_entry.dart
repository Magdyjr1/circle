import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer'; // For log
import 'home.dart'; // For navigation

class InvitationEntry extends StatefulWidget {
  final User user; // Authenticated user from Supabase
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
  bool _isAutoSubmitting = false;

  // --- IMPORTANT: DEFINE YOUR LIMITS HERE ---
  static const int MAX_USAGE_LIMIT = 2; // Example: Code can be used by 2 different users.

  @override
  void initState() {
    super.initState();
    // Check for pre-filled data from userMetadata
    final metadata = widget.user.userMetadata;
    if (metadata != null) {
      final String? prefilledUsername = metadata['username'] as String?;
      final String? prefilledInviteCode = metadata['invitation_code'] as String?;

      if (prefilledUsername != null && prefilledUsername.isNotEmpty && prefilledInviteCode != null && prefilledInviteCode.isNotEmpty) {
        _usernameController.text = prefilledUsername;
        _invitationCodeController.text = prefilledInviteCode;
        log('Prefilled data found. Preparing for auto-submission.');
        setState(() {
          _isAutoSubmitting = true;
        });
        // Call submit after the first frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _submitInvitation();
        });
      }
    }
  }

  @override
  void dispose() {
    _invitationCodeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submitInvitation() async {
    // If this is a manual submission, validate the form. For auto-submission, the controllers are pre-filled.
    if (!_isAutoSubmitting && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final enteredCode = _invitationCodeController.text.trim();
    final enteredUsername = _usernameController.text.trim();
    
    int? validInvitationIdAsInt; 

    try {
      // 1. Validate invitation code
      log('Validating invitation code: $enteredCode for user ID: ${widget.user.id}');
      final invitationResponse = await _supabase
          .from('invitation_codes')
          .select('id, usage_count, invited_users') 
          .eq('code', enteredCode)
          .maybeSingle();

      if (invitationResponse == null) {
        throw 'Invalid invitation code.';
      }
      
      validInvitationIdAsInt = invitationResponse['id'] as int?; 
      if (validInvitationIdAsInt == null) {
        throw 'Invitation code ID not found (this should not happen if record exists).';
      }

      final currentUsageCount = invitationResponse['usage_count'] as int? ?? 0;
      List<String> invitedUserIds = [];
      if (invitationResponse['invited_users'] != null) {
        invitedUserIds = (invitationResponse['invited_users'] as List).map((item) => item.toString()).toList();
      }

      if (invitedUserIds.contains(widget.user.id)) {
        log('Warning: User ${widget.user.id} trying to use code $enteredCode which they are already listed under. This is a retry scenario.');
      } else if (currentUsageCount >= MAX_USAGE_LIMIT) { 
        throw 'This invitation code has reached its maximum usage limit.';
      }
      
      log('Invitation code validated. ID: $validInvitationIdAsInt');

      // 2. Check username availability
      log('Checking username availability: $enteredUsername');
      final usernameResponse = await _supabase
          .from('profiles')
          .select('id') 
          .eq('username', enteredUsername)
          .maybeSingle();

      if (usernameResponse != null && usernameResponse['id'] != widget.user.id) {
        throw 'Username "$enteredUsername" is already taken. Please choose another.';
      }
      log('Username "$enteredUsername" is available.');

      // 3. Create or Update profile in 'profiles' table using upsert
      log('Upserting profile for user: ${widget.user.id} with username: $enteredUsername');
      await _supabase.from('profiles').upsert({
        'id': widget.user.id, 
        'username': enteredUsername,
        'email': widget.user.email,
      }, onConflict: 'id');
      log('Profile created/updated successfully.');

      // 4. Update invitation code if user is new to this code
      if (!invitedUserIds.contains(widget.user.id)) {
        log('Updating invitation code $validInvitationIdAsInt for new user ${widget.user.id}.');
        invitedUserIds.add(widget.user.id);
        await _supabase
            .from('invitation_codes')
            .update({
              'usage_count': currentUsageCount + 1,
              'invited_users': invitedUserIds,
            })
            .eq('id', validInvitationIdAsInt); 
        log('Invitation code updated successfully.');
      }
      
      log('Signup completion successful. Navigating to Home with username: $enteredUsername');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Home(username: enteredUsername)),
          (route) => false,
        );
      }

    } catch (e) {
      log('Error during signup process: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          // If auto-submission fails, show the form so the user can see the error.
          _isAutoSubmitting = false; 
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
    // If auto-submitting, show a loading screen.
    if (_isAutoSubmitting && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Completing sign up...',
                style: TextStyle(fontSize: 18, color: Color(0xFF1B2E47)),
              ),
            ],
          ),
        ),
      );
    }
    
    // Otherwise, show the form for manual entry (Google Sign-In) or to display errors.
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
            // Floating back button
            if (!_isAutoSubmitting)
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
                        'You are signed in as: ${widget.user.email ?? 'N/A'}\nPlease complete your registration.',
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
