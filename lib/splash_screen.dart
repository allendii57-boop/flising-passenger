import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added to check login status

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  _initializeApp() async {
    // 1. Simulate a premium loading sequence
    print("Flising Passenger: Booting up platform...");
    await Future.delayed(const Duration(seconds: 3));

    // 2. The Gatekeeper: Check if the user is already logged in
    if (mounted) {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // User has an active account -> go to Map
        Navigator.pushReplacementNamed(context, '/passenger_main');
      } else {
        // First time opening or logged out -> go to Login
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Flising Premium Dark
      body: Stack(
        children: [
          // 1. Central Content (Logo, PASSENGER, Spinner)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The Official Logo
                Image.asset(
                  'assets/images/flising_logo.png', // Matches pubspec exactly
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),

                // Passenger Designation
                const Text(
                  "FLISING PASSENGER",
                  style: TextStyle(
                    color: Color(0xFFE9692C),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 2.0, // Premium spacing
                  ),
                ),
                const SizedBox(height: 50),

                // The Premium Orange Spinner
                const CircularProgressIndicator(
                  color: Color(0xFFE9692C), // Flising Orange
                  strokeWidth: 3.0,
                ),
              ],
            ),
          ),

          // 2. Bottom Hometown Tagline
          const Positioned(
            bottom: 60, // Pulled up from 30 to perfectly match the driver app!
            left: 0,
            right: 0,
            child: Text(
              "FROM VANIMO TO THE WORLD",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}