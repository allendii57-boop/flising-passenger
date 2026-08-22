import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Save token to database
    await saveToken();

    // Token refresh
    _fcm.onTokenRefresh.listen((_) => saveToken());

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((message) {
      print('Foreground: ${message.notification?.title}');
    });

    // Background handler
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler
    );
  }

  static Future<void> saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app')
        .ref('passengers/${user.uid}/fcmToken')
        .set(token);
  }
}
