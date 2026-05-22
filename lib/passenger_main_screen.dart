import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'live_map.dart';
import 'passenger_history.dart';
import 'passenger_profile.dart';
import 'quick_places_list.dart'; 

class PassengerMainScreen extends StatefulWidget {
  const PassengerMainScreen({super.key});

  @override
  State<PassengerMainScreen> createState() => _PassengerMainScreenState();
}

class _PassengerMainScreenState extends State<PassengerMainScreen> {
  late GoogleMapController mapController;
  
  // 1. STATE VARIABLES
  LatLng _myLocation = const LatLng(-2.6741, 141.3028); // Vanimo Default
  LatLng? _customPickupLocation;
  bool _isSettingPickup = false;
  LatLng? _dropoffLocation;
  String _pickupText = "Fetching location...";
  String _dropoffText = "Tap map to set dropoff...";
  String _estimatedFare = "K 0.00";
  double _calculatedFareAmount = 0.0;
  
  String _rideStatus = 'IDLE';
  String? _currentRideId;
  StreamSubscription<DatabaseEvent>? _ticketListener;
  StreamSubscription<DatabaseEvent>? _driverLocationListener;
  StreamSubscription<Position>? _locationStream;
  
  String? _assignedDriverId;
  LatLng? _driverLocation;
  bool _showCancelButton = false;
  bool _showCompletionPopup = false;
  String? _lastCompletedRideId;
    String? _driverName;
String? _driverPhone;
String? _driverPhoto;
  int _givenRating = 0;
  int _selectedView = 0;
  
  bool _isVerified = false; 
  bool _hasInitialZoomed = false; 
  
  // NEW: Track GPS state for the badge
  bool _isAcquiringGps = false; 
    bool _hasAcquiredLocation = false;

  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);

  @override
  void initState() {
    super.initState();
    _goToMyLocation();
    _checkVerificationStatus(); 
  }

  @override
  void dispose() {
    _ticketListener?.cancel();
    _driverLocationListener?.cancel();
    super.dispose();
  }

  // 2. GATEKEEPER LOGIC
  void _checkVerificationStatus() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
    DatabaseReference userRef = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
).ref('users/passengers/${user.uid}/isVerified');
      userRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _isVerified = event.snapshot.value as bool;
          });
        }
      });
    }
  }

 // 3. MAP & GPS LOGIC (Updated for Premium "Zoom-In" feel)
  Future<void> _goToMyLocation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(
          const LatLng(-2.6741, 141.3028), 14.0));
    } catch(e) {
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
      
      setState(() => _isAcquiringGps = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30));

      if (!mounted) return;

      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
        _pickupText = "My Current Location";
        _isAcquiringGps = false;
        _hasAcquiredLocation = true; 
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(_myLocation, 16.5));
      _hasInitialZoomed = true;
_locationStream = Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  ),
).listen((Position position) {
  if (mounted && _rideStatus == 'IDLE') {
    setState(() {
      _myLocation = LatLng(position.latitude, position.longitude);
      if (_customPickupLocation == null) {
        _pickupText = "My Current Location";
      }
    });
  }
});

    } catch (e) {
      if (mounted) {
        setState(() => _isAcquiringGps = false);
      }
      print("GPS Timeout: $e");
    }
  }

    Future<void> _calculateFare() async {
  if (_dropoffLocation == null) return;
  final activePickup = _customPickupLocation ?? _myLocation;
  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${activePickup.latitude},${activePickup.longitude}'
      '&destination=${_dropoffLocation!.latitude},${_dropoffLocation!.longitude}'
      '&key=AIzaSyB455Y5mJwyYGdmd0OLj8IHirxn4OqNo_A'
    );
    final response = await http.get(url);
    final data = json.decode(response.body);
    if (data['status'] == 'OK') {
      final meters = data['routes'][0]['legs'][0]['distance']['value'];
      final distanceInKm = meters / 1000.0;
      final rawFare = 10.00 + (distanceInKm * 5.00);
      final finalFare = rawFare.ceilToDouble();
      if (mounted) setState(() {
        _calculatedFareAmount = finalFare;
        _estimatedFare = "K ${finalFare.toStringAsFixed(2)}";
      });
    } else {
      _calculateFareStraightLine();
    }
  } catch (e) {
    _calculateFareStraightLine();
  }
}

void _calculateFareStraightLine() {
  if (_dropoffLocation == null) return;
  final activePickup = _customPickupLocation ?? _myLocation;
  final distanceInMeters = Geolocator.distanceBetween(
    activePickup.latitude, activePickup.longitude,
    _dropoffLocation!.latitude, _dropoffLocation!.longitude);
  final distanceInKm = distanceInMeters / 1000;
  final rawFare = 10.00 + (distanceInKm * 5.00);
  final finalFare = rawFare.ceilToDouble();
  if (mounted) setState(() {
    _calculatedFareAmount = finalFare;
    _estimatedFare = "K ${finalFare.toStringAsFixed(2)}";
  });
}

  void _handleMapTap(LatLng point) {
    if (_rideStatus != 'IDLE' || _showCompletionPopup) return;
    setState(() {
      if (_isSettingPickup) {
        _customPickupLocation = point;
        _pickupText = "Custom Map Pickup";
        _isSettingPickup = false;
      } else {
        _dropoffLocation = point;
        _dropoffText = "Custom Map Dropoff";
      }
    });
    _calculateFare();
  }
    
  void _showLocationSearchSheet(bool isPickup) {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(isPickup ? "Where are we picking you up?" : "Where to?", 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: vanimoLocations.length,
                itemBuilder: (context, index) {
                  final place = vanimoLocations[index];
                  return ListTile(
                    leading: Icon(Icons.location_on, color: flisingOrange),
                    title: Text(place['name'] as String, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        LatLng newPoint = LatLng(place['lat'] as double, place['lng'] as double);
                        if (isPickup) {
                          _customPickupLocation = newPoint;
                          _pickupText = place['name'] as String;
                        } else {
                          _dropoffLocation = newPoint;
                          _dropoffText = place['name'] as String;
                        }
                      });
                      _calculateFare();
                      mapController.animateCamera(CameraUpdate.newLatLngZoom(LatLng(place['lat'] as double, place['lng'] as double), 15.5));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bc) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Select Payment Method", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: flisingOrange.withOpacity(0.5))),
              child: ListTile(
                leading: Icon(Icons.payments, color: flisingOrange, size: 30),
                title: const Text("Cash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Pay driver directly", style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _findClosestDriver();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. THE HANDSHAKE ENGINE (FIREBASE)
  void _findClosestDriver() async {
  setState(() { _rideStatus = 'SEARCHING'; });
  _locationStream?.cancel();

  User? currentUser = FirebaseAuth.instance.currentUser;
  final db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Find nearest online driver
  final driversSnap = await db.ref('drivers').get();
  String? closestDriverId;
  double closestDistance = double.infinity;

  if (driversSnap.exists) {
    final driversMap = driversSnap.value as Map<dynamic, dynamic>;
    driversMap.forEach((driverId, driverData) {
      if (driverData is! Map) return;
      final isOnline = driverData['isOnline'] as bool? ?? false;
      if (!isOnline) return;
      final lat = (driverData['latitude'] as num?)?.toDouble();
      final lng = (driverData['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      final dist = Geolocator.distanceBetween(
        _myLocation.latitude, _myLocation.longitude, lat, lng);
      if (dist < closestDistance) {
        closestDistance = dist;
        closestDriverId = driverId as String;
      }
    });
  }

  if (closestDriverId == null) {
    if (mounted) {
      setState(() { _rideStatus = 'IDLE'; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No drivers online right now. Please try again.'),
        backgroundColor: Colors.red,
      ));
    }
    return;
  }

  // Create ride with real driver UID
  final ridesRef = db.ref('rides');
  String newRideId = ridesRef.push().key!;
  _currentRideId = newRideId;

  await db.ref('rides/$newRideId').set({
    'passengerId': currentUser?.uid ?? 'unknown_passenger',
    'assignedDriverId': closestDriverId,
    'pickupText': _pickupText,
    'dropoffText': _dropoffText,
    'fare': _estimatedFare,
    'paymentMethod': 'CASH',
    'pickupLat': (_customPickupLocation ?? _myLocation).latitude,
    'pickupLng': (_customPickupLocation ?? _myLocation).longitude,
    'dropoffLat': _dropoffLocation!.latitude,
    'dropoffLng': _dropoffLocation!.longitude,
    'status': 'PENDING',
    'timestamp': ServerValue.timestamp,
  });

  _ticketListener = db.ref('rides/$newRideId').onValue.listen((event) {
    if (event.snapshot.exists) {
      final rideData = event.snapshot.value as Map<dynamic, dynamic>;
      String currentStatus = rideData['status'];
      if (!mounted) return;

      if (currentStatus == 'ACCEPTED' && _rideStatus != 'ACCEPTED') {
        setState(() {
          _rideStatus = 'ACCEPTED';
          _assignedDriverId = rideData['assignedDriverId'];
          _showCancelButton = false;
        });
        _startTrackingDriver();
        Timer(const Duration(seconds: 5), () {
          if (mounted && _rideStatus == 'ACCEPTED') setState(() { _showCancelButton = true; });
        });
      } else if (currentStatus == 'IN_PROGRESS' && _rideStatus != 'IN_PROGRESS') {
        setState(() { _rideStatus = 'IN_PROGRESS'; _showCancelButton = false; });
      } else if (currentStatus == 'COMPLETED') {
        setState(() {
          _lastCompletedRideId = _currentRideId;
          _rideStatus = 'IDLE';
          _currentRideId = null;
          _showCompletionPopup = true;
        });
        _ticketListener?.cancel();
        _stopTrackingDriver();
      }
    }
  });

  Future.delayed(const Duration(seconds: 60), () {
    if (mounted && _rideStatus == 'SEARCHING') {
      _cancelRide();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No response from driver. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
    }
  });
  }
  

  void _startTrackingDriver() {
    if (_assignedDriverId == null) return;
    DatabaseReference driverRef = FirebaseDatabase.instance.ref('drivers/$_assignedDriverId');
      FirebaseDatabase.instance
    .ref('drivers/$_assignedDriverId/profile')
    .once()
    .then((snap) {
  final d = snap.snapshot.value as Map<dynamic, dynamic>?;
  if (d != null && mounted) {
    setState(() {
      _driverName = d['fullName'] ?? 'Driver';
      _driverPhone = d['phoneNumber'] ?? '';
      _driverPhoto = d['photoUrl'];
    });
  }
});
    _driverLocationListener = driverRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (data['latitude'] != null && data['longitude'] != null) {
          setState(() {
            _driverLocation = LatLng(data['latitude'], data['longitude']);
          });
        }
      }
    });
  }

  void _stopTrackingDriver() {
    _driverLocationListener?.cancel();
    _driverLocation = null;
  }

  void _cancelRide() {
    setState(() { _rideStatus = 'IDLE'; _showCancelButton = false; });
    if (_currentRideId != null) {
      FirebaseDatabase.instance.ref('rides/$_currentRideId').update({'status': 'CANCELLED_BY_PASSENGER'});
      _currentRideId = null;
    }
    _stopTrackingDriver();
    _ticketListener?.cancel();
  }

  void _submitRating() async {
    if (_lastCompletedRideId != null && _givenRating > 0) {
      DatabaseReference rideRef = FirebaseDatabase.instance.ref('rides/$_lastCompletedRideId');
      await rideRef.update({'rating': _givenRating});
    }
    setState(() {
      _showCompletionPopup = false;
      _dropoffLocation = null;
      _estimatedFare = "K 0.00";
      _dropoffText = "Tap map to set dropoff...";
    });
  }

  // 5. THE UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedView,
        children: [
          Stack(
            children: [
              LiveMap(
                myLocation: _myLocation,
                customPickupLocation: _customPickupLocation,
                dropoffLocation: _dropoffLocation,
                driverLocation: _driverLocation,
                onMapCreated: (controller) => mapController = controller,
                onTap: _handleMapTap,
              ),
              
              // NEW: The Acquiring GPS Badge (Matches the Driver App)
              if (_isAcquiringGps)
                Positioned(
                  top: 60, // Sits nicely below the status bar
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: flisingOrange.withOpacity(0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(flisingOrange),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Acquiring GPS...",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_rideStatus == 'IDLE') ...[
                          Row(
                            children: [
                              GestureDetector(
  onTap: () {
    setState(() {
      _customPickupLocation = null;
      _pickupText = "My Current Location";
    });
    mapController.animateCamera(CameraUpdate.newLatLngZoom(_myLocation, 16.0));
  },
  child: Icon(Icons.my_location, color: flisingOrange, size: 20),
),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_pickupText, style: const TextStyle(color: Colors.white, fontSize: 16))),
                              IconButton(icon: const Icon(Icons.search, color: Colors.white54), onPressed: () => _showLocationSearchSheet(true)),
                            ],
                          ),
                          const Divider(color: Colors.white12),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: _dropoffLocation != null ? flisingOrange : Colors.white54, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_dropoffText, style: const TextStyle(color: Colors.white, fontSize: 16))),
                              IconButton(icon: const Icon(Icons.search, color: Colors.white54), onPressed: () => _showLocationSearchSheet(false)),
                            ],
                          ),
                          const SizedBox(height: 12),
if (_dropoffLocation != null)
  Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: flisingOrange.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(Icons.payments_outlined, color: flisingOrange, size: 18),
          const SizedBox(width: 8),
          const Text("Estimated Fare", style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
        Text(_estimatedFare, style: TextStyle(color: flisingOrange, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ),
  ),
                          ElevatedButton(
                            onPressed: () {
                              if (!_isVerified) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Please go to profile to complete verification'),
                                  backgroundColor: flisingOrange,
                                ));
                              } else if (_dropoffLocation != null) {
                                _showPaymentSelection();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Set a dropoff location first'),
                                  backgroundColor: flisingOrange,
                                ));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isVerified ? flisingOrange : Colors.grey[850],
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("REQUEST RIDE", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                        
                        if (_rideStatus == 'SEARCHING') ...[
                          const CircularProgressIndicator(color: Color(0xFFE9692C)),
                          const SizedBox(height: 20),
                          const Text("Finding your premium ride...", style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: _cancelRide, child: const Text("CANCEL")),
                        ],
                        
                        if (_rideStatus == 'ACCEPTED') ...[
                          const Text("DRIVER ON THE WAY", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
  backgroundImage: _driverPhoto != null
      ? NetworkImage(_driverPhoto!) : null,
  child: _driverPhoto == null
      ? const Icon(Icons.person, color: Colors.white) : null,
),
                              const SizedBox(width: 16),
   Text(_driverName ?? 'Driver'),
                              IconButton(
                                icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
 onPressed: () => launchUrl(
    Uri(scheme: 'tel', path: _driverPhone ?? '')),
                              ),
                            ],
                          ),
                          if (_showCancelButton) ElevatedButton(onPressed: _cancelRide, child: const Text("CANCEL RIDE")),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              if (_showCompletionPopup) Container(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: flisingOrange, size: 60),
                        const SizedBox(height: 20),
                        const Text("Thank you for choosing Flising.", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) => IconButton(
                            icon: Icon(index < _givenRating ? Icons.star : Icons.star_border, color: flisingOrange),
                            onPressed: () => setState(() => _givenRating = index + 1),
                          )),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(onPressed: _submitRating, child: const Text("SUBMIT")),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const PassengerHistory(),
          const PassengerProfilePage(),
        ],
      ),
      bottomNavigationBar: _rideStatus == 'IDLE' && !_showCompletionPopup ? BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: flisingOrange,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedView,
        onTap: (index) => setState(() => _selectedView = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Ride'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ) : null,
    );
  }
}
