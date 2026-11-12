import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Uint8List? _profileImageBytes;
  String _userName = "Flising Passenger";
  String _userEmail = "Loading...";
  String _userPhone = "";
  bool _uploadingPhoto = false;

  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);
  final String supportWhatsAppNumber = "67584171054";

  DatabaseReference _userRef(String uid) => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref('users/passengers/$uid');

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
  }

  void _loadUserProfileData() {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() {
      _userEmail = _currentUser!.email ?? "No Email Provided";
      if (_currentUser!.phoneNumber != null && _currentUser!.phoneNumber!.isNotEmpty) {
        _userPhone = _currentUser!.phoneNumber!;
      }
      _userName = (_currentUser!.displayName != null && _currentUser!.displayName!.isNotEmpty)
          ? _currentUser!.displayName!
          : _userEmail.split('@')[0].toUpperCase();
    });

    _userRef(_currentUser!.uid).onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = (event.snapshot.value as Map?) ?? {};
        setState(() {
          _profileImageUrl = data['profileImageUrl']?.toString();
          if (data['profileImageBase64'] != null && data['profileImageBase64'].toString().isNotEmpty) {
            try {
              _profileImageBytes = base64Decode(data['profileImageBase64'].toString());
            } catch (_) {}
          }
          if (data['name'] != null && data['name'].toString().isNotEmpty) {
            _userName = data['name'].toString();
          } else if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            _userName = data['fullName'].toString();
          }
          if (data['phoneNumber'] != null && data['phoneNumber'].toString().isNotEmpty) {
            _userPhone = data['phoneNumber'].toString();
          } else if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
            _userPhone = data['phone'].toString();
          }
        });
      }
    });
  }

  ImageProvider? _avatarImageProvider() {
    if (_profileImageBytes != null) return MemoryImage(_profileImageBytes!);
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) return NetworkImage(_profileImageUrl!);
    return null;
  }

  Future<void> _changeAvatar() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 420, maxHeight: 420, imageQuality: 65);
      if (picked == null || _currentUser == null) return;
      setState(() => _uploadingPhoto = true);

      final uid = _currentUser!.uid;
      final fileBytes = await File(picked.path).readAsBytes();

      try {
        final ref = FirebaseStorage.instance.ref().child('passenger_profiles/$uid/avatar.jpg');
        await ref.putFile(File(picked.path));
        final url = await ref.getDownloadURL();
        await _userRef(uid).update({'profileImageUrl': url});
      } catch (_) {
        // Fallback when Firebase Storage rules block passenger_profiles: store directly in RTDB!
        final b64 = base64Encode(fileBytes);
        await _userRef(uid).update({'profileImageBase64': b64});
      }

      if (mounted) {
        setState(() {
          _profileImageBytes = fileBytes;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo updated successfully!'),
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

  Future<void> _editFieldDialog({required String title, required String fieldKey, required String initialValue, TextInputType keyboard = TextInputType.text}) async {
    final ctrl = TextEditingController(text: initialValue);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $title',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: flisingOrange),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty && _currentUser != null) {
                await _userRef(_currentUser!.uid).update({fieldKey: val});
                if (fieldKey == 'name') {
                  await _userRef(_currentUser!.uid).update({'fullName': val});
                }
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    const message = "Hi Flising Support, I need help with my Passenger app.";
    final Uri whatsappUrl = Uri.parse("https://wa.me/$supportWhatsAppNumber?text=${Uri.encodeComponent(message)}");
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarImageProvider();
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildDrawer(avatarProvider),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
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
                    const Text("Profile", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAvatar(avatarProvider),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _editFieldDialog(title: 'Full Name', fieldKey: 'name', initialValue: _userName),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _infoCard(),
              const SizedBox(height: 24),
              _linkTile(Icons.favorite_border, "Saved Places", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerSavedPlacesPage()));
              }),
              _linkTile(Icons.history, "Ride History", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerHistory()));
              }),
              _linkTile(Icons.account_balance_wallet_outlined, "Payment Methods", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerPaymentsPage()));
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ImageProvider? avatarProvider) {
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
              boxShadow: [BoxShadow(color: flisingOrange.withOpacity(0.35), blurRadius: 22, spreadRadius: 2)],
              image: avatarProvider != null ? DecorationImage(image: avatarProvider, fit: BoxFit.cover) : null,
            ),
            child: avatarProvider == null
                ? Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : "P",
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: flisingOrange),
                    ),
                  )
                : null,
          ),
          if (!_uploadingPhoto)
            Positioned(
              bottom: 4,
              right: MediaQuery.of(context).size.width / 2 - 60 - 4,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: flisingOrange, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          if (_uploadingPhoto)
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          _infoRow(Icons.email_outlined, "Email", _userEmail, null),
          const Divider(color: Colors.white10, height: 1, indent: 56),
          _infoRow(
            Icons.phone_outlined,
            "Phone (Tap to edit)",
            _userPhone.isEmpty ? "Not provided" : _userPhone,
            () => _editFieldDialog(title: 'Phone Number', fieldKey: 'phoneNumber', initialValue: _userPhone, keyboard: TextInputType.phone),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: flisingOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: flisingOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.edit_outlined, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: flisingOrange, size: 22),
                const SizedBox(width: 16),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(ImageProvider? avatarProvider) {
    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [flisingOrange.withOpacity(0.3), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: darkSurface,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(_userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : "P",
                            style: TextStyle(color: flisingOrange, fontSize: 24, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_userEmail, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.history, color: flisingOrange),
              title: const Text("Ride History", style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerHistory()));
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined, color: flisingOrange),
              title: const Text("Payments", style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerPaymentsPage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.support_agent, color: flisingOrange),
              title: const Text("Help & Support", style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _launchWhatsApp();
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFE53935)),
              title: const Text("Log Out", style: TextStyle(color: Color(0xFFE53935))),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
