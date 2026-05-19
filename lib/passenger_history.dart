import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerHistory extends StatelessWidget {
  const PassengerHistory({super.key});

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black, // Dark premium background
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "My Rides",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Slightly wider padding for premium feel
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- THE FIREBASE LISTENER ---
              Expanded(
                child: currentUser == null
                    ? const Center(
                        child: Text("Please log in to see history", style: TextStyle(color: Colors.white70)),
                      )
                    : StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instanceFor(
                          app: Firebase.app(),
                          databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
                        ).ref().child('rides').orderByChild('passengerId').equalTo(currentUser.uid).onValue,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              // Premium Flising Orange Spinner
                              child: CircularProgressIndicator(color: Color(0xFFE9692C)),
                            );
                          }

                          List<Map<dynamic, dynamic>> completedRides = [];

                          // 1. Filter out only the COMPLETED rides
                          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                            Map<dynamic, dynamic> ridesData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                            ridesData.forEach((key, value) {
                              if (value['status'] == 'COMPLETED') {
                                completedRides.add(value);
                              }
                            });
                          }

                          // 2. Sort them newest to oldest
                          completedRides.sort((a, b) {
                            int timeA = a['timestamp'] ?? 0;
                            int timeB = b['timestamp'] ?? 0;
                            return timeB.compareTo(timeA);
                          });

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- DYNAMIC PREMIUM SUMMARY CARD ---
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C1E), // Dark sleek grey
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2C2E)), // Subtle border
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9692C).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.directions_car_filled,
                                        color: Color(0xFFE9692C), // Flising Orange
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "TOTAL COMPLETED RIDES",
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${completedRides.length}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),
                              const Text(
                                "Recent Trips",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 15),

                              // --- DYNAMIC HISTORY LIST ---
                              Expanded(
                                child: completedRides.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "No completed rides yet.\nRequest a ride to get started!",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white54, height: 1.5),
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(bottom: 80), // Prevents nav bar overlap
                                        itemCount: completedRides.length,
                                        itemBuilder: (context, index) {
                                          var ride = completedRides[index];

                                          // Format Timestamp
                                          String dateText = "Unknown Date";
                                          if (ride['timestamp'] != null) {
                                            DateTime date = DateTime.fromMillisecondsSinceEpoch(ride['timestamp']);
                                            List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                            dateText = "${months[date.month - 1]} ${date.day}, ${date.year}";
                                          }

                                          String dropoff = ride['dropoffText'] ?? "Unknown Dropoff";
                                          String cost = ride['fare'] ?? "K 0.00";
                                          String driverName = "Flising Driver"; // Placeholder for future feature

                                          return _buildHistoryRow(dateText, dropoff, cost, driverName);
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

  // --- PREMIUM HISTORY ROW UI ---
  Widget _buildHistoryRow(String date, String dropoff, String cost, String driverName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Match summary card background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date & Cost
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFE9692C), // Flising Orange
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                cost,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Dropoff Location
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white54, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dropoff,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Driver Info
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 18),
              const SizedBox(width: 12),
              Text(
                driverName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}