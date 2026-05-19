import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerSettingsPage extends StatelessWidget {
  const PassengerSettingsPage({super.key});

  void _performLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }

  // Helper function to show "Coming Soon" for inactive settings
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature settings will be available in the next update.', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE9692C),
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Account Security", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: Colors.white70),
                    title: const Text("Notifications", style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => _showComingSoon(context, "Notification"),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.white70),
                    title: const Text("Privacy & Security", style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => _showComingSoon(context, "Privacy"),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.white70),
                    title: const Text("Language", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("English", style: TextStyle(color: Colors.white30, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => _showComingSoon(context, "Language"),
                  ),
                ],
              ),
            ),
            
            const Spacer(), 
            
            ElevatedButton(
              onPressed: () => _performLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white),
                  SizedBox(width: 10),
                  Text("SECURE LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}