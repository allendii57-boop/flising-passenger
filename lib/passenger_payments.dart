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
    // Enforce cash as default while BSP Mobile is locked
    _selectedMethod = 'cash';
    _userRef()?.update({'preferredPayment': 'cash'});
  }

  Future<void> _selectMethod(String method, String label, {bool locked = false}) async {
    if (locked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('BSP Mobile / Transfer is currently locked. Please use Cash Payment (Kina).'),
        backgroundColor: Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
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
    bool locked = false,
  }) {
    final active = !locked && _selectedMethod == id;
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? flisingOrange : Colors.white12, width: 1.5),
        ),
        child: ListTile(
          onTap: () => _selectMethod(id, title, locked: locked),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (locked ? Colors.grey : flisingOrange).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: locked ? Colors.white38 : flisingOrange, size: 28),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: locked ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LOCKED',
                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Icon(
            locked
                ? Icons.lock_outline
                : (active ? Icons.check_circle : Icons.radio_button_unchecked),
            color: locked ? Colors.white38 : (active ? flisingOrange : Colors.white30),
            size: 24,
          ),
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
              locked: false,
            ),
            _methodCard(
              id: 'bsp_mobile',
              icon: Icons.phone_android_outlined,
              title: "BSP Mobile / Transfer",
              subtitle: "Unavailable for now (Cash Only)",
              locked: true,
            ),
          ],
        ),
      ),
    );
  }
}
