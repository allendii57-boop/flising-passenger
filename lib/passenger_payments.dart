import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerPaymentsPage extends StatefulWidget {
  const PassengerPaymentsPage({super.key});

  @override
  State<PassengerPaymentsPage> createState() => _PassengerPaymentsPageState();
}

class _PassengerPaymentsPageState extends State<PassengerPaymentsPage> {
  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);
  String _selectedMethod = 'cash';

  DatabaseReference? _userRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref('users/passengers/$uid');
  }

  @override
  void initState() {
    super.initState();
    _userRef()?.child('preferredPayment').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() => _selectedMethod = snap.value.toString());
      }
    });
  }

  Future<void> _selectMethod(String method, String label) async {
    setState(() => _selectedMethod = method);
    await _userRef()?.update({'preferredPayment': method});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Default payment set to $label'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _methodCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final active = _selectedMethod == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? flisingOrange : Colors.white12, width: 1.5),
      ),
      child: ListTile(
        onTap: () => _selectMethod(id, title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: flisingOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: flisingOrange, size: 28),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          color: active ? flisingOrange : Colors.white30,
          size: 24,
        ),
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
        title: const Text("Payment Methods", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SELECT DEFAULT PAYMENT METHOD", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),
            _methodCard(
              id: 'cash',
              icon: Icons.payments_outlined,
              title: "Cash Payment (Kina)",
              subtitle: "Pay your driver directly in cash",
            ),
            _methodCard(
              id: 'bsp_mobile',
              icon: Icons.phone_android_outlined,
              title: "BSP Mobile / Transfer",
              subtitle: "Transfer directly to driver on arrival",
            ),
          ],
        ),
      ),
    );
  }
}
