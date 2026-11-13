import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerHistory extends StatelessWidget {
  const PassengerHistory({super.key});

  String _formatDateTime(dynamic ts) {
    if (ts is! num) return 'Unknown Date & Time';
    final d = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hr = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} • $hr:$min $ampm';
  }

  double _parseFare(dynamic v) =>
      double.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

  void _showTripReceipt(BuildContext context, Map ride, String dateTimeStr) {
    final pickup = (ride['pickupText'] ?? 'Current Location').toString();
    final dropoff = (ride['dropoffText'] ?? 'Unknown Dropoff').toString();
    final cost = (ride['fare'] ?? 'K 0.00').toString();
    final driverName = (ride['driverName'] ?? 'Flising Driver').toString();
    final type = ride['type'] == 'delivery' ? 'Parcel Delivery' : 'Passenger Ride';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Trip Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(cost, style: const TextStyle(color: Color(0xFFE9692C), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateTimeStr, style: const TextStyle(color: Color(0xFFE9692C), fontSize: 12, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white12, height: 22),
            const Text('FROM (PICKUP)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(pickup, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            const Text('TO (DROPOFF)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(dropoff, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Divider(color: Colors.white12, height: 22),
            Text('Service: $type', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Driver: $driverName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9692C)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('My Rides', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: currentUser == null
                    ? const Center(child: Text('Please log in to see history', style: TextStyle(color: Colors.white70)))
                    : StreamBuilder(
                        stream: FirebaseDatabase.instanceFor(
                          app: Firebase.app(),
                          databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
                        ).ref().child('rides').orderByChild('passengerId').equalTo(currentUser.uid).onValue,
                        builder: (context, AsyncSnapshot snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFFE9692C)));
                          }
                          final List completedRides = [];
                          double totalSpent = 0.0;
                          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                            final ridesData = snapshot.data!.snapshot.value as Map;
                            ridesData.forEach((key, value) {
                              if (value is Map && value['status'] == 'COMPLETED') {
                                completedRides.add(value);
                                totalSpent += _parseFare(value['fare']);
                              }
                            });
                          }
                          completedRides.sort((a, b) => (((b as Map)['timestamp'] ?? 0) as num).compareTo(((a as Map)['timestamp'] ?? 0) as num));
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2C2E)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('TOTAL COMPLETED RIDES', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('${completedRides.length}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text('Recent Trips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 12),
                              Expanded(
                                child: completedRides.isEmpty
                                    ? const Center(child: Text('No completed rides yet.', style: TextStyle(color: Colors.white54)))
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(bottom: 80),
                                        itemCount: completedRides.length,
                                        itemBuilder: (context, index) {
                                          final ride = completedRides[index] as Map;
                                          final dateTimeText = _formatDateTime(ride['timestamp']);
                                          final pickup = (ride['pickupText'] ?? 'Current Location').toString();
                                          final dropoff = (ride['dropoffText'] ?? 'Unknown Dropoff').toString();
                                          final cost = (ride['fare'] ?? 'K 0.00').toString();
                                          final driverName = (ride['driverName'] ?? 'Flising Driver').toString();
                                          return GestureDetector(
                                            onTap: () => _showTripReceipt(context, ride, dateTimeText),
                                            child: _buildHistoryRow(dateTimeText, pickup, dropoff, cost, driverName),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(String dateTime, String pickup, String dropoff, String cost, String driverName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateTime.toUpperCase(), style: const TextStyle(color: Color(0xFFE9692C), fontSize: 11, fontWeight: FontWeight.bold)),
              Text(cost, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text('From: $pickup', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFE9692C), size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text('To: $dropoff', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 16),
              const SizedBox(width: 10),
              Text(driverName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}