import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// MAIN SETTINGS PAGE
// ─────────────────────────────────────────────
class PassengerSettingsPage extends StatelessWidget {
  const PassengerSettingsPage({super.key});

  void _performLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Secure Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account Security',
                style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: Colors.white70),
                    title: const Text('Notifications', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsPage())),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.white70),
                    title: const Text('Privacy & Security', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityPage())),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.white70),
                    title: const Text('Language', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('English', style: TextStyle(color: Colors.white30, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSettingsPage())),
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
                  Text('SECURE LOGOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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

// ─────────────────────────────────────────────
// NOTIFICATIONS PAGE
// ─────────────────────────────────────────────
class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _rideUpdates = true;
  bool _promotions = false;
  bool _driverArrival = true;
  bool _tripReceipts = true;
  bool _soundEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Push Notifications'),
            const SizedBox(height: 10),
            _settingsCard([
              _switchTile(icon: Icons.directions_car_outlined, title: 'Ride Updates', subtitle: 'Status changes during your trip', value: _rideUpdates, onChanged: (v) => setState(() => _rideUpdates = v)),
              _divider(),
              _switchTile(icon: Icons.person_pin_circle_outlined, title: 'Driver Arrival', subtitle: 'Alert when driver is nearby', value: _driverArrival, onChanged: (v) => setState(() => _driverArrival = v)),
              _divider(),
              _switchTile(icon: Icons.receipt_long_outlined, title: 'Trip Receipts', subtitle: 'Receipts after every completed trip', value: _tripReceipts, onChanged: (v) => setState(() => _tripReceipts = v)),
              _divider(),
              _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions & Offers', subtitle: 'Deals, discounts, and news', value: _promotions, onChanged: (v) => setState(() => _promotions = v)),
            ]),
            const SizedBox(height: 24),
            _sectionLabel('Sound'),
            const SizedBox(height: 10),
            _settingsCard([
              _switchTile(icon: Icons.volume_up_outlined, title: 'Notification Sound', subtitle: 'Play sound for alerts', value: _soundEnabled, onChanged: (v) => setState(() => _soundEnabled = v)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PRIVACY & SECURITY PAGE
// ─────────────────────────────────────────────
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _locationSharing = true;
  bool _twoFactor = false;
  bool _biometric = false;
  bool _shareRideStatus = true;

  void _showInfo(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Color(0xFFE9692C))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Privacy & Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Privacy'),
            const SizedBox(height: 10),
            _settingsCard([
              _switchTile(icon: Icons.location_on_outlined, title: 'Live Location Sharing', subtitle: 'Share location during active rides', value: _locationSharing, onChanged: (v) => setState(() => _locationSharing = v)),
              _divider(),
              _switchTile(icon: Icons.share_outlined, title: 'Share Ride Status', subtitle: 'Let contacts track your trip', value: _shareRideStatus, onChanged: (v) => setState(() => _shareRideStatus = v)),
            ]),
            const SizedBox(height: 24),
            _sectionLabel('Security'),
            const SizedBox(height: 10),
            _settingsCard([
              _switchTile(icon: Icons.verified_user_outlined, title: 'Two-Factor Authentication', subtitle: 'Extra layer of login security', value: _twoFactor, onChanged: (v) => setState(() => _twoFactor = v)),
              _divider(),
              _switchTile(icon: Icons.fingerprint, title: 'Biometric Login', subtitle: 'Use fingerprint or face ID', value: _biometric, onChanged: (v) => setState(() => _biometric = v)),
              _divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                onTap: () => _showInfo(context, 'Delete Account', 'To permanently delete your account, please contact support at support@yourapp.com.'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LANGUAGE PAGE
// ─────────────────────────────────────────────
class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _selected = 'English';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
    {'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
    {'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
    {'name': 'Portuguese', 'native': 'Português', 'flag': '🇧🇷'},
    {'name': 'Swahili', 'native': 'Kiswahili', 'flag': '🇰🇪'},
    {'name': 'Chinese', 'native': '中文', 'flag': '🇨🇳'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Select Language'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _languages.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1, indent: 50),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selected == lang['name'];
                  return ListTile(
                    leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(lang['name']!, style: TextStyle(color: isSelected ? const Color(0xFFE9692C) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(lang['native']!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFE9692C)) : null,
                    onTap: () {
                      setState(() => _selected = lang['name']!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Language set to ${lang['name']}', style: const TextStyle(color: Colors.white)),
                          backgroundColor: const Color(0xFFE9692C),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────
Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
    );

Widget _settingsCard(List<Widget> children) => Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );

Widget _divider() => const Divider(color: Colors.white12, height: 1, indent: 50);

Widget _switchTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) =>
    SwitchListTile(
      secondary: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFE9692C),
      inactiveThumbColor: Colors.white38,
      inactiveTrackColor: Colors.white12,
    );
