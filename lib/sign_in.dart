// In lib/sign_in.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Added for SVG support
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';
import 'sign_up.dart'; 
import 'forgot_password.dart'; 

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
    
    print('Sign in attempt - Email: "$email", Password length: \${password.length}');

    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('✅ Sign in successful for user: \${res.user?.email}');
      
      if (mounted && res.user != null) {
        final profileResponse = await supabase
            .from('profiles')
            .select('username')
            .eq('id', res.user!.id)
            .single();
        
        final username = profileResponse['username'] as String? ?? res.user!.email?.split('@').first ?? 'User';
        print('✅ Username fetched: $username');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Home(username: username)),
        );
      }
    } on AuthException catch (e) {
      print('❌ AuthException: \${e.message}');
      print('❌ Error details: \${e.toString()}');
      
      String errorMessage = 'Sign in failed: \${e.message}';
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
      print('❌ General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: \${e.toString()}'),
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
                        // Ensuring navigation is to ForgotPasswordScreen
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
                  
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          // TODO: Implement Facebook Sign In
                          print('Facebook sign-in tapped');
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0), // Same padding as Google
                            child: SvgPicture.asset(
                              'assets/icons/facebook_icon.svg',
                              height: 50.0,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 35), // Spacer between icons
                      GestureDetector(
                        onTap: () {
                          // TODO: Implement Google Sign In
                          print('Google sign-in tapped');
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: SvgPicture.asset(
                              'assets/icons/google_icon.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
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
