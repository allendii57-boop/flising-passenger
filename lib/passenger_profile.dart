import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import 'passenger_history.dart';
import 'passenger_settings.dart';
import 'passenger_verification_page.dart';
import 'passenger_payments.dart';
import 'passenger_saved_places.dart';

class PassengerProfilePage extends StatefulWidget {
  const PassengerProfilePage({super.key});
  @override
  State<PassengerProfilePage> createState() => _PassengerProfilePageState();
}

class _PassengerProfilePageState extends State<PassengerProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _profileImageUrl;

  String _userName = "Flising Passenger";
  String _userStatus = "LOADING STATUS...";
  String _userEmail = "Loading...";
  Color _statusColor = Colors.white54;

  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);
  final String supportWhatsAppNumber = "67584171054";

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
  }

_loadUserProfileData() async {
  _currentUser = _auth.currentUser;
  if (_currentUser != null) {
    if (mounted) {
      setState(() {
        _userEmail = _currentUser!.email ?? "No Email Provided";
        if (_currentUser!.displayName != null && _currentUser!.displayName!.isNotEmpty) {
          _userName = _currentUser!.displayName!;
        } else {
          _userName = _userEmail.split('@')[0].toUpperCase();
        }
      });
    }
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref()
          .child('users/passengers/${_currentUser!.uid}');
      userRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          Map data = event.snapshot.value as Map;
          setState(() {
            _profileImageUrl = data['profileImageUrl'];
            bool isVerified = data['isVerified'] ?? false;
            _userStatus = isVerified ? "VERIFIED PASSENGER" : "PENDING VERIFICATION";
            _statusColor = isVerified ? const Color(0xFF4CAF50) : flisingOrange;
            if (data['name'] != null && data['name'].toString().isNotEmpty) {
              _userName = data['name'];
            }
          });
        }
      });
    } catch (e) {
      print("Error fetching profile data: $e");
    }
  } else {
    Navigator.pushReplacementNamed(context, '/login');
  }
}

  Future<void> _launchWhatsApp() async {
    const message = "Hi Flising Support, I need help with my Passenger app.";
    final Uri whatsappUrl = Uri.parse("https://wa.me/$supportWhatsAppNumber?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open WhatsApp. Please ensure it is installed.'),
          backgroundColor: flisingOrange,
        ));
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
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: flisingOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: flisingOrange, width: 2),
                      image: _profileImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImageUrl == null
                        ? Center(
                            child: Text(
                              _userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : "P",
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFFE9692C)),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _statusColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusColor == flisingOrange ? Icons.pending_actions : Icons.verified, color: _statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                _userStatus,
                                style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_userEmail, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildProfileTile(
              icon: Icons.shield_outlined,
              title: "Verification Portal",
              subtitle: "Manage ID and documents",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PassengerVerificationPage()));
              },
            ),
            _buildProfileTile(
              icon: Icons.account_balance_wallet_outlined,
              title: "Payment Methods",
              subtitle: "Cash & Cards",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PassengerPaymentsPage()));
              },
            ),
            _buildProfileTile(
              icon: Icons.favorite_border,
              title: "Saved Places",
              subtitle: "Home, Work, etc.",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PassengerSavedPlacesPage()));
              },
            ),
            _buildProfileTile(
              icon: Icons.history,
              title: "Ride History",
              subtitle: "View past trips & receipts",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PassengerHistory()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Divider(color: Colors.white12),
            ),
            _buildProfileTile(
              icon: Icons.support_agent,
              title: "Help & Support",
              subtitle: "Chat with us directly on WhatsApp",
              onTap: _launchWhatsApp,
            ),
            _buildProfileTile(
              icon: Icons.settings_outlined,
              title: "Account & Settings",
              subtitle: "Security, Language, Logout",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PassengerSettingsPage()));
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
        onTap: onTap,
      ),
    );
  }
}
