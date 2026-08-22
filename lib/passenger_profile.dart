import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'passenger_history.dart';
import 'passenger_payments.dart';
import 'passenger_saved_places.dart';

class PassengerProfilePage extends StatefulWidget {
  const PassengerProfilePage({super.key});
  @override
  State<PassengerProfilePage> createState() => _PassengerProfilePageState();
}

class _PassengerProfilePageState extends State<PassengerProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  User? _currentUser;

  String? _profileImageUrl;
  String _userName = "Flising Passenger";
  String _userEmail = "Loading...";
  String _userPhone = "";
  bool _uploadingPhoto = false;

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
    if (_currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (mounted) {
      setState(() {
        _userEmail = _currentUser!.email ?? "No Email Provided";
        if (_currentUser!.displayName != null &&
            _currentUser!.displayName!.isNotEmpty) {
          _userName = _currentUser!.displayName!;
        } else {
          _userName = _userEmail.split('@')[0].toUpperCase();
        }
      });
    }
    try {
      DatabaseReference userRef = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app')
          .ref()
          .child('users/passengers/${_currentUser!.uid}');
      userRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          Map data = event.snapshot.value as Map;
          setState(() {
            _profileImageUrl = data['profileImageUrl'];
            if (data['name'] != null &&
                data['name'].toString().isNotEmpty) {
              _userName = data['name'];
            } else if (data['fullName'] != null &&
                data['fullName'].toString().isNotEmpty) {
              _userName = data['fullName'];
            }
            if (data['phoneNumber'] != null) {
              _userPhone = data['phoneNumber'].toString();
            } else if (data['phone'] != null) {
              _userPhone = data['phone'].toString();
            }
          });
        }
      });
    } catch (e) {
      debugPrint("Error fetching profile data: $e");
    }
  }

  // Tap avatar -> pick + upload a new profile image (optional)
  Future<void> _changeAvatar() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);

      final uid = _currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('passenger_profiles/$uid/avatar.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app')
          .ref('users/passengers/$uid')
          .update({'profileImageUrl': url});

      if (mounted) {
        setState(() {
          _profileImageUrl = url;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Color(0xFF4CAF50),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not update photo: $e'),
          backgroundColor: flisingOrange,
        ));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    const message = "Hi Flising Support, I need help with my Passenger app.";
    final Uri whatsappUrl = Uri.parse(
        "https://wa.me/$supportWhatsAppNumber?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Could not open WhatsApp. Please ensure it is installed.'),
          backgroundColor: flisingOrange,
        ));
      }
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showPromoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Promo Code',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter code',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: flisingOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: flisingOrange),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Promo codes coming soon!'),
                backgroundColor: Color(0xFF1C1C1E),
              ));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // top bar with menu button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                    const Spacer(),
                    const Text("Profile",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAvatar(),
              const SizedBox(height: 18),
              Text(
                _userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 28),
              // contact info card
              _infoCard(),
              const SizedBox(height: 24),
              // quick links
              _linkTile(Icons.favorite_border, "Saved Places", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerSavedPlacesPage()));
              }),
              _linkTile(Icons.history, "Ride History", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerHistory()));
              }),
              _linkTile(Icons.account_balance_wallet_outlined,
                  "Payment Methods", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerPaymentsPage()));
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- AVATAR ----------
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _uploadingPhoto ? null : _changeAvatar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: darkSurface,
              border: Border.all(color: flisingOrange, width: 3),
              boxShadow: [
                BoxShadow(
                  color: flisingOrange.withOpacity(0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
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
                      _userName.isNotEmpty
                          ? _userName.substring(0, 1).toUpperCase()
                          : "P",
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: flisingOrange),
                    ),
                  )
                : null,
          ),
          // camera badge
          if (!_uploadingPhoto)
            Positioned(
              bottom: 4,
              right: MediaQuery.of(context).size.width / 2 - 60 - 4,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: flisingOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 16),
              ),
            ),
          if (_uploadingPhoto)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Colors.white),
            ),
        ],
      ),
    );
  }

  // ---------- INFO CARD ----------
  Widget _infoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _infoRow(Icons.email_outlined, "Email", _userEmail),
          Divider(color: Colors.white10, height: 1, indent: 56),
          _infoRow(Icons.phone_outlined, "Phone",
              _userPhone.isEmpty ? "Not provided" : _userPhone),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: flisingOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: flisingOrange, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- LINK TILE ----------
  Widget _linkTile(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: flisingOrange, size: 22),
                const SizedBox(width: 16),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- SIDE DRAWER ----------
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: SafeArea(
        child: Column(
          children: [
            // drawer header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    flisingOrange.withOpacity(0.3),
                    Colors.transparent
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: darkSurface,
                    backgroundImage: _profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: _profileImageUrl == null
                        ? Text(
                            _userName.isNotEmpty
                                ? _userName.substring(0, 1).toUpperCase()
                                : "P",
                            style: TextStyle(
                                color: flisingOrange,
                                fontSize: 24,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(_userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_userEmail,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(Icons.local_offer_outlined, "Promo Codes", () {
              Navigator.pop(context);
              _showPromoDialog();
            }),
            _drawerItem(Icons.history, "Ride History", () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PassengerHistory()));
            }),
            _drawerItem(Icons.account_balance_wallet_outlined, "Payments",
                () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PassengerPaymentsPage()));
            }),
            _drawerItem(Icons.support_agent, "Help & Support", () {
              Navigator.pop(context);
              _launchWhatsApp();
            }),
            const Spacer(),
            Divider(color: Colors.white10, indent: 16, endIndent: 16),
            _drawerItem(Icons.logout, "Log Out", () {
              Navigator.pop(context);
              _logout();
            }, danger: true),
            const SizedBox(height: 12),
            Text("FLISING",
                style: TextStyle(
                    color: flisingOrange.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? const Color(0xFFE53935) : Colors.white70;
    return ListTile(
      leading: Icon(icon, color: danger ? color : flisingOrange, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
