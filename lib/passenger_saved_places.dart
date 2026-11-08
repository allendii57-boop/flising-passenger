import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerSavedPlacesPage extends StatefulWidget {
  const PassengerSavedPlacesPage({super.key});

  @override
  State<PassengerSavedPlacesPage> createState() => _PassengerSavedPlacesPageState();
}

class _PassengerSavedPlacesPageState extends State<PassengerSavedPlacesPage> {
  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);

  DatabaseReference? _placesRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref('users/passengers/$uid/savedPlaces');
  }

  Future<void> _editPlaceDialog({
    required String keyName,
    required String title,
    String currentAddress = '',
    bool isCustom = false,
  }) async {
    final labelCtrl = TextEditingController(text: isCustom ? '' : title);
    final addrCtrl = TextEditingController(text: currentAddress);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isCustom ? 'Add Custom Place' : 'Set $title Address',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              TextField(
                controller: labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Place Label (e.g. Gym, Market, Family)',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: addrCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Address or Landmark in Vanimo',
                hintText: 'e.g. East Tawa Back Street / Wesan Camp',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (!isCustom && currentAddress.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _placesRef()?.child(keyName).remove();
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: flisingOrange),
            onPressed: () async {
              final addr = addrCtrl.text.trim();
              if (addr.isEmpty) return;
              final ref = _placesRef();
              if (ref != null) {
                if (isCustom) {
                  final lbl = labelCtrl.text.trim().isEmpty ? 'Saved Place' : labelCtrl.text.trim();
                  await ref.child('custom').push().set({'label': lbl, 'address': addr});
                } else {
                  await ref.child(keyName).set(addr);
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

  @override
  Widget build(BuildContext context) {
    final ref = _placesRef();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Saved Places", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ref == null
          ? const Center(child: Text("Please log in", style: TextStyle(color: Colors.white54)))
          : StreamBuilder<DatabaseEvent>(
              stream: ref.onValue,
              builder: (context, snapshot) {
                final data = (snapshot.data?.snapshot.value as Map?) ?? {};
                final homeAddr = (data['home'] ?? '').toString();
                final workAddr = (data['work'] ?? '').toString();
                final customMap = (data['custom'] as Map?) ?? {};

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text("FAVORITES", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 15),
                    Container(
                      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          _buildPlaceTile(
                            icon: Icons.home_outlined,
                            title: homeAddr.isEmpty ? "Add Home" : "Home",
                            subtitle: homeAddr.isEmpty ? "Set your home address" : homeAddr,
                            isSaved: homeAddr.isNotEmpty,
                            onTap: () => _editPlaceDialog(keyName: 'home', title: 'Home', currentAddress: homeAddr),
                          ),
                          const Divider(color: Colors.white12, height: 1, indent: 60),
                          _buildPlaceTile(
                            icon: Icons.work_outline,
                            title: workAddr.isEmpty ? "Add Work" : "Work",
                            subtitle: workAddr.isEmpty ? "Set your workplace" : workAddr,
                            isSaved: workAddr.isNotEmpty,
                            onTap: () => _editPlaceDialog(keyName: 'work', title: 'Work', currentAddress: workAddr),
                          ),
                          const Divider(color: Colors.white12, height: 1, indent: 60),
                          _buildPlaceTile(
                            icon: Icons.add_location_alt_outlined,
                            title: "Add Custom Place",
                            subtitle: "Gym, Market, Family, etc.",
                            isSaved: false,
                            onTap: () => _editPlaceDialog(keyName: 'custom', title: 'Custom', isCustom: true),
                          ),
                        ],
                      ),
                    ),
                    if (customMap.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const Text("CUSTOM PLACES", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 12),
                      ...customMap.entries.map((e) {
                        final item = (e.value as Map?) ?? {};
                        final lbl = (item['label'] ?? 'Place').toString();
                        final addr = (item['address'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: Icon(Icons.place, color: flisingOrange),
                            title: Text(lbl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(addr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => ref.child('custom/${e.key}').remove(),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPlaceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSaved,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: isSaved ? flisingOrange : Colors.white70, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: isSaved ? flisingOrange : Colors.white54, fontSize: 12)),
      trailing: Icon(isSaved ? Icons.edit_outlined : Icons.arrow_forward_ios, color: Colors.white30, size: 15),
      onTap: onTap,
    );
  }
}
