// lib/home.dart

import 'package:flutter/material.dart';
import 'package:circle/main.dart'; // Keep this one
// import 'package:circle/sign_in.dart'; // User requested removal, but needed for SignIn() navigation

class Home extends StatelessWidget {
  final String username; 

  const Home({super.key, required this.username});

  Future<void> _handleLogout(BuildContext context) async {
    await supabase.auth.signOut(); // Now this will use the supabase from main.dart
    if (context.mounted) {
      // The following line requires 'package:circle/sign_in.dart' to be imported
      // to resolve the SignIn() widget.
      // If SignIn is not imported, this will cause a compilation error.
      // Consider re-adding: import 'package:circle/sign_in.dart';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Placeholder()), // Temporary placeholder 
        // MaterialPageRoute(builder: (context) => const SignIn()), // Original line
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'circle',
          style: TextStyle(
            color: Color(0xFF205692),
            fontSize: 30,
            fontFamily: 'Katahdin Round',
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1B2E47)),
            onPressed: () => _handleLogout(context),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 39.0),
            child: Center(
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
                  const SizedBox(height: 10),
                  const Text(
                    'HOME',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1B2E47),
                      fontSize: 36,
                      fontFamily: 'Katahdin Round',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Text(
                    'Welcome $username!\nYou are logged in.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1B2E47),
                      fontSize: 20,
                      fontFamily: 'Poppins', 
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => _handleLogout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF558DCA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(53),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Poppins',
                          // fontWeight seems to be cut off in user's prompt, using previous value
                          fontWeight: FontWeight.w500, 
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
