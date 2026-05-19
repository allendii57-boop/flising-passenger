import 'package:flutter/material.dart';

class PassengerSavedPlacesPage extends StatelessWidget {
  const PassengerSavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Saved Places", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FAVORITES", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),
            
            // Container grouping the places
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildPlaceTile(icon: Icons.home_outlined, title: "Add Home", subtitle: "Set your home address"),
                  const Divider(color: Colors.white12, height: 1, indent: 60),
                  _buildPlaceTile(icon: Icons.work_outline, title: "Add Work", subtitle: "Set your workplace"),
                  const Divider(color: Colors.white12, height: 1, indent: 60),
                  _buildPlaceTile(icon: Icons.add_location_alt_outlined, title: "Add Custom Place", subtitle: "Gym, Family, etc."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceTile({required IconData icon, required String title, required String subtitle}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: Colors.white70, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
      onTap: () {
        // Future feature: Open a map picker here
      },
    );
  }
}