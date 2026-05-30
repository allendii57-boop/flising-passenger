import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'passenger_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Start the app immediately; notifications init in background (non-blocking)
  runApp(const FlisingPassengerApp());

  NotificationService.initialize().catchError((e) {
    debugPrint('Notification init error: $e');
  });
}

class FlisingPassengerApp extends StatelessWidget {
  const FlisingPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flising Passenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const PassengerLoginScreen(),
        '/register': (context) => const PassengerRegisterScreen(),
        '/splash': (context) => const SplashScreen(),
        '/passenger_main': (context) => const PassengerMainScreen(),
      },
    );
  }
}
