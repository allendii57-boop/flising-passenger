import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // REQUIRED to prevent the blank screen crash!

// Your local screen imports
import 'login_screen.dart';
import 'splash_screen.dart';
import 'passenger_main_screen.dart';
import 'register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Waking up Firebase with the proper platform options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FlisingPassengerApp());
}

class FlisingPassengerApp extends StatelessWidget {
  const FlisingPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flising Passenger',
      debugShowCheckedModeBanner: false, // Removes the red "DEBUG" banner
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black, // Flising Dark Theme
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // The app now boots DIRECTLY to the Splash Screen
      home: StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()));
    }
    if (snapshot.hasData) return const SplashScreen();
    return const LoginScreen();
  },
),

      // Your app's map of routes
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/splash': (context) => const SplashScreen(),
        '/passenger_main': (context) => const PassengerMainScreen(),
      },
    );
  }
}
