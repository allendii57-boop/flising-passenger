import 'package:flutter/material.dart';

class PassengerPaymentsPage extends StatelessWidget {
  const PassengerPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Payment Methods", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ACTIVE METHODS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),
            
            // Premium Active Cash Tile
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9692C), width: 1.5), // Orange active border
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE9692C).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.payments_outlined, color: Color(0xFFE9692C), size: 28),
                ),
                title: const Text("Cash Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text("Pay your driver directly", style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.check_circle, color: Color(0xFFE9692C), size: 24),
              ),
            ),
            
            const SizedBox(height: 35),
            const Text("DIGITAL WALLETS & CARDS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),
            
            // Locked Digital Wallet Tile
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.credit_card, color: Colors.white30, size: 28),
                ),
                title: const Text("Add Visa / Mastercard", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text("Feature unlocking soon", style: TextStyle(color: Colors.white30, fontSize: 12)),
                trailing: const Icon(Icons.lock_outline, color: Colors.white30, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card payments are coming in a future update!'), backgroundColor: Color(0xFFE9692C), behavior: SnackBarBehavior.floating)
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