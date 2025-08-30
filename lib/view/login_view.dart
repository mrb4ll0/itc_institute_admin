import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:itc_institute_admin/view/home/institute_auth/institute_code_page.dart';

import 'home/home_page.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<UserCredential?> _signInWithGoogle() async {
    try {
       await GoogleSignIn().signOut();
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google login failed: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage("assets/logo.png"),
              ),
              const SizedBox(height: 40),

              // Welcome text
              const Text(
                "Welcome Back 👋",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Sign in with Google to continue",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 50),

              // Google login button
              ElevatedButton.icon(
                onPressed: () async {
                  final user = await _signInWithGoogle();
                  if (user != null) {
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>  InstitutionCodePage(),
                        ),
                      );
                    }
                  }
                },
                icon: Image.asset("assets/google.png", height: 24),
                label: const Text("Continue with Google"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

