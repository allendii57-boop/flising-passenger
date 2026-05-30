import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  bool _isVerified = false;

  // Quick stats (real data, with graceful fallbacks)
  String _rideCount = "—";
  String _memberSince = "—";

  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);
  final String supportWhatsAppNumber = "67584171054";

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
    _loadStats();
  }

  _loadUserProfileData() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
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
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref()
            .child('users/passengers/${_currentUser!.uid}');
        userRef.onValue.listen((event) {
          if (event.snapshot.exists && mounted) {
            Map data = event.snapshot.value as Map;
            setState(() {
              _profileImageUrl = data['profileImageUrl'];
              bool isVerified = data['isVerified'] ?? false;
              _isVerified = isVerified;
              _userStatus =
                  isVerified ? "VERIFIED PASSENGER" : "PENDING VERIFICATION";
              _statusColor =
                  isVerified ? const Color(0xFF4CAF50) : flisingOrange;
              if (data['name'] != null &&
                  data['name'].toString().isNotEmpty) {
                _userName = data['name'];
              }
              // member-since from registeredAt (epoch millis) if present
              final reg = data['registeredAt'];
              if (reg is int) {
                final d = DateTime.fromMillisecondsSinceEpoch(reg);
                _memberSince = _shortMonthYear(d);
              }
            });
          }
        });
      } catch (e) {
        debugPrint("Error fetching profile data: $e");
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Pull a real completed-ride count for this passenger from the rides node.
  _loadStats() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('rides')
          .orderByChild('passengerId')
          .equalTo(user.uid)
          .get();
      if (snap.exists && mounted) {
        int completed = 0;
        final rides = snap.value as Map<dynamic, dynamic>;
        rides.forEach((key, value) {
          if (value is Map && value['status'] == 'COMPLETED') completed++;
        });
        setState(() => _rideCount = completed.toString());
      } else if (mounted) {
        setState(() => _rideCount = "0");
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
    }
  }

  String _shortMonthYear(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 28),
              _sectionLabel("ACCOUNT"),
              _buildProfileTile(
                icon: Icons.shield_outlined,
                title: "Verification Portal",
                subtitle: "Manage ID and documents",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerVerificationPage())),
              ),
              _buildProfileTile(
                icon: Icons.account_balance_wallet_outlined,
                title: "Payment Methods",
                subtitle: "Cash & Cards",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerPaymentsPage())),
              ),
              const SizedBox(height: 18),
              _sectionLabel("ACTIVITY"),
              _buildProfileTile(
                icon: Icons.favorite_border,
                title: "Saved Places",
                subtitle: "Home, Work, etc.",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerSavedPlacesPage())),
              ),
              _buildProfileTile(
                icon: Icons.history,
                title: "Ride History",
                subtitle: "View past trips & receipts",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerHistory())),
              ),
              const SizedBox(height: 18),
              _sectionLabel("SUPPORT"),
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
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PassengerSettingsPage())),
              ),
              const SizedBox(height: 36),
              _buildAppVersion(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- HEADER ----------
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            flisingOrange.withOpacity(0.28),
            flisingOrange.withOpacity(0.06),
            Colors.black,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // top bar: title + back
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
              ),
              const Spacer(),
              const Text("My Profile",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 24),
          // avatar
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: flisingOrange, width: 3),
              boxShadow: [
                BoxShadow(
                  color: flisingOrange.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
              color: darkSurface,
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
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: flisingOrange),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          // name
          Text(
            _userName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // email
          Text(_userEmail,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),
          // verified badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _statusColor.withOpacity(0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isVerified ? Icons.verified : Icons.pending_actions,
                    color: _statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  _userStatus,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- STATS ----------
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard(Icons.route, _rideCount, "Total Rides"),
          const SizedBox(width: 12),
          _statCard(Icons.calendar_today, _memberSince, "Member Since"),
          const SizedBox(width: 12),
          _statCard(
              _isVerified ? Icons.verified_user : Icons.lock_clock,
              _isVerified ? "Active" : "Pending",
              "Status"),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: flisingOrange, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SECTION LABEL ----------
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4),
      ),
    );
  }

  // ---------- TILE ----------
  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: flisingOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: flisingOrange, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Column(
        children: [
          Text("FLISING",
              style: TextStyle(
                  color: flisingOrange.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4)),
          const SizedBox(height: 4),
          const Text("FROM VANIMO TO THE WORLD",
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 2)),
        ],
      ),
    );
  }
}
