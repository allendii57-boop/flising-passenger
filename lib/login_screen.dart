import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true; // Controls password visibility

  _login() async {
    // Zero-Error Polish: Prevent empty submissions before hitting Firebase
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter your email and password.',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFE9692C),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // SECURITY GATE: Check if email is verified
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut(); // Kick them back out
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Please verify your email address first. Check your inbox!',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFFD32F2F), // Red warning
            duration: Duration(seconds: 4),
          ));
        }
        return;
      }

      if (mounted) {
  try {
    final uid = userCredential.user!.uid;
    final ref = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app', // ✅ fixed
).ref('users/passengers/$uid');
    final snapshot = await ref.get()
        .timeout(Duration(seconds: 5));
    if (!snapshot.exists) {
      await ref.set({
        'fullName': userCredential.user!.displayName ?? '',
        'email': userCredential.user!.email ?? '',
        'createdAt': DateTime.now().toIso8601String(),
        'isVerified': false,
        'role': 'passenger',
      }).timeout(Duration(seconds: 5));
    }
  } catch (e) {
    print('DB skipped: $e');
  }
  Navigator.pushReplacementNamed(context, '/splash');
}

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login Failed: ${e.message}";
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(errorMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFE9692C),
        ));
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
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/flising_logo.png',
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.local_taxi,
                    color: Color(0xFFE9692C), size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Passenger Login",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Connect to your Premium Ride Platform.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 50),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE9692C)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // PASSWORD WITH SHOW TOGGLE
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE9692C)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE9692C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text(
                  "New to Flising? Sign Up",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
