import 'chat_screen.dart';
import 'dart:math';
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
import 'route_service.dart';
import 'passenger_history.dart';
import 'passenger_profile.dart';
import 'quick_places_list.dart'; 
import 'call_screen.dart';
import 'service_areas.dart';

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
  String _estimatedETA = "";
  double _calculatedFareAmount = 0.0;
  
  String _vehicleType = 'car';
  bool _isPanelMinimized = false; // 'car' or 'motorcycle'
  String _rideStatus = 'IDLE';
  String? _currentRideId;
  StreamSubscription<DatabaseEvent>? _ticketListener;
  StreamSubscription<DatabaseEvent>? _incomingCallListener;
  bool _callScreenOpen = false;
  bool _isRideCardMinimized = false;
  StreamSubscription<DatabaseEvent>? _driverLocationListener;
  StreamSubscription<Position>? _locationStream;
  
  List<LatLng> _routePoints = [];
  String? _assignedDriverId;
  LatLng? _driverLocation;
  double _driverHeading = 0;
  bool _showCancelButton = false;
  int _cancelSecondsLeft = 120;
  bool _showCompletionPopup = false;
  String? _lastCompletedRideId;
    String? _driverName;
String? _driverPhone;
  String get _driverFirstName {
    final n = (_driverName ?? '').trim();
    return n.isEmpty ? 'Driver' : n.split(' ').first;
  }
  bool _isSendMode = false;
  String _deliveryPin = '';
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _parcelNoteCtrl = TextEditingController();
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
    _restoreActiveRide();
    _goToMyLocation();
    _checkVerificationStatus(); 
  }

  @override
  void _watchIncomingCall(String rideId) {
    _incomingCallListener?.cancel();
    _incomingCallListener = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref('rides/$rideId/call').onValue.listen((event) {
      if (!event.snapshot.exists || !mounted || _callScreenOpen) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      if (data['status'] != 'CALLING') return;
      if (data['callerType'] != 'driver') return;
      _callScreenOpen = true;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          rideId: rideId,
          isIncoming: true,
          callerType: 'passenger',
          otherPersonName: _driverFirstName,
          otherPersonPhoto: _driverPhoto,
        ),
      )).then((_) => _callScreenOpen = false);
    });
  }

  void _stopWatchingIncomingCall() {
    _incomingCallListener?.cancel();
    _incomingCallListener = null;
  }

  void dispose() {
    _recipientNameCtrl.dispose(); _recipientPhoneCtrl.dispose(); _parcelNoteCtrl.dispose();
    _incomingCallListener?.cancel();
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
      final perKm = _isSendMode ? 5.00 : (_vehicleType == 'motorcycle' ? 5.50 : 6.70);
      final rawFare = distanceInKm * perKm;
      // Round up to the nearest 0.10 (10 toea)
      final finalFare = (double.parse(rawFare.toStringAsFixed(2)) * 10).ceil() / 10.0;
      if (mounted) setState(() {
        _calculatedFareAmount = finalFare;
        _estimatedFare = "K ${finalFare.toStringAsFixed(2)}";
          final encoded = data['routes'][0]['overview_polyline']['points'];
          _routePoints = RouteService.decodePolyline(encoded as String);
          // Auto-zoom to fit the route
          if (_routePoints.isNotEmpty) {
            double minLat = _routePoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
            double maxLat = _routePoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
            double minLng = _routePoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
            double maxLng = _routePoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mapController.animateCamera(
                CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(minLat, minLng),
                    northeast: LatLng(maxLat, maxLng),
                  ),
                  80.0,
                ),
              );
            });
          }
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
  final distanceInKm = (distanceInMeters / 1000) * 1.3; // approx road distance
  final perKm = _isSendMode ? 5.00 : (_vehicleType == 'motorcycle' ? 5.50 : 6.70);
      final rawFare = distanceInKm * perKm;
      // Round up to the nearest 0.10 (10 toea)
      final finalFare = (double.parse(rawFare.toStringAsFixed(2)) * 10).ceil() / 10.0;
  if (mounted) setState(() {
    _calculatedFareAmount = finalFare;
    _estimatedFare = "K ${finalFare.toStringAsFixed(2)}";
  });
}

  Widget _modeOption(bool send, IconData icon, String label) {
    final selected = _isSendMode == send;
    return GestureDetector(
      onTap: () { setState(() => _isSendMode = send); _calculateFare(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? flisingOrange.withOpacity(0.15) : Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? flisingOrange : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? flisingOrange : Colors.white54, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sendField(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: c,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: flisingOrange, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          isDense: true,
          filled: true,
          fillColor: Colors.white10,
          contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Future<void> _textPinToRecipient() async {
    final phone = _recipientPhoneCtrl.text.trim();
    final msg = 'Your Flising delivery PIN is $_deliveryPin. Give it to the driver when your parcel arrives.';
    await launchUrl(Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappPinToRecipient() async {
    String digits = _recipientPhoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length >= 7 && digits.length <= 8 && !digits.startsWith('675')) {
      digits = '675$digits';
    }
    final msg = 'Your Flising delivery PIN is $_deliveryPin. Give it to the driver when your parcel arrives.';
    final waAppUri = Uri.parse('whatsapp://send?phone=$digits&text=${Uri.encodeComponent(msg)}');
    final waWebUri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(msg)}');
    try {
      final launched = await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _vehicleOption(String type, IconData icon, String label, String rate) {
    final bool selected = _vehicleType == type;
    return GestureDetector(
      onTap: () {
        if (_vehicleType == type) return;
        setState(() => _vehicleType = type);
        _calculateFare();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? flisingOrange.withOpacity(0.18) : Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? flisingOrange : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? flisingOrange : Colors.white54, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(rate, style: TextStyle(
                    color: selected ? flisingOrange : Colors.white38,
                    fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _inArea(LatLng? p, [String what = 'That location']) {
    if (p == null || currentServiceArea.contains(p)) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what is outside the ${currentServiceArea.name} service area'),
      backgroundColor: Colors.red,
    ));
    return false;
  }

  void _handleMapTap(LatLng point) {
    if (_rideStatus != 'IDLE' || _showCompletionPopup) return;
    if (!_inArea(point, _isSettingPickup ? 'Pickup' : 'Dropoff')) return;
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
      isScrollControlled: true,
      backgroundColor: darkSurface,
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
                          if (_inArea(newPoint, 'Pickup')) { _customPickupLocation = newPoint;
                          _pickupText = place['name'] as String; }
                        } else {
                          if (_inArea(newPoint, 'Dropoff')) { _dropoffLocation = newPoint;
                          _dropoffText = place['name'] as String; }
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
      isScrollControlled: true,
      backgroundColor: darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bc) => Padding(
        padding: EdgeInsets.only(
          top: 24.0, left: 20.0, right: 20.0,
          bottom: 24.0 + MediaQuery.of(bc).padding.bottom,
        ),
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
    if (!_inArea(_customPickupLocation ?? _myLocation, 'Pickup') || !_inArea(_dropoffLocation, 'Dropoff')) return;
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
      // Only match drivers with the requested vehicle type (legacy drivers = car)
      final dProfile = driverData['profile'];
      String dType = 'car';
      if (dProfile is Map && dProfile['vehicleType'] != null) {
        dType = dProfile['vehicleType'].toString();
      } else if (driverData['vehicleType'] != null) {
        dType = driverData['vehicleType'].toString();
      }
      if (dType != _vehicleType) return;
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
  _currentRideId = newRideId; _watchIncomingCall(newRideId); _deliveryPin = _isSendMode ? (1000 + Random().nextInt(9000)).toString() : '';

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
    'vehicleType': _vehicleType,
    if (_isSendMode) ...{
      'type': 'delivery',
      'recipientName': _recipientNameCtrl.text.trim(),
      'recipientPhone': _recipientPhoneCtrl.text.trim(),
      'parcelNote': _parcelNoteCtrl.text.trim(),
      'deliveryPin': _deliveryPin,
    },
    'status': 'PENDING',
    'timestamp': ServerValue.timestamp,
  });

  _listenToRide(newRideId);

  Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_cancelSecondsLeft > 0) {
        setState(() => _cancelSecondsLeft--);
      } else {
        timer.cancel();
        if (mounted) setState(() { _showCancelButton = false; _cancelSecondsLeft = 120; });
      }
    });
    Future.delayed(const Duration(seconds: 30), () {
    if (mounted && _rideStatus != 'ACCEPTED' && _rideStatus != 'IN_PROGRESS') {
      _cancelRide();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No response from driver. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
    }
  });
  }
  

  void _listenToRide(String rideId) {
    _ticketListener?.cancel();
    _ticketListener = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app').ref('rides/$rideId').onValue.listen((event) {
    if (event.snapshot.exists) {
      final rideData = event.snapshot.value as Map<dynamic, dynamic>;
      String currentStatus = rideData['status'];
      if (!mounted) return;

      if (currentStatus == 'ACCEPTED' && _rideStatus != 'ACCEPTED') {
        setState(() {
          _rideStatus = 'ACCEPTED';
          _assignedDriverId = rideData['assignedDriverId'];
          if (rideData['driverName'] != null) _driverName = rideData['driverName'].toString();
          if (rideData['driverPhoto'] != null) _driverPhoto = rideData['driverPhoto'].toString();
          _showCancelButton = false;
        });
        _startTrackingDriver();
        Timer(const Duration(seconds: 5), () {
          if (mounted && _rideStatus == 'ACCEPTED') setState(() { _showCancelButton = true; });
        });
      } else if (currentStatus == 'IN_PROGRESS' && _rideStatus != 'IN_PROGRESS') {
        final isDeliveryRide = rideData['type'] == 'delivery' || _isSendMode || _deliveryPin.isNotEmpty;
        if (isDeliveryRide) {
          setState(() {
            _lastCompletedRideId = _currentRideId;
            _rideStatus = 'IDLE';
            _currentRideId = null;
            _stopWatchingIncomingCall();
            _showCancelButton = false;
            _showCompletionPopup = true;
          });
          _ticketListener?.cancel();
          _stopTrackingDriver();
        } else {
          setState(() { _rideStatus = 'IN_PROGRESS'; _showCancelButton = false; });
        }
      } else if (currentStatus.startsWith('CANCELLED') && currentStatus != 'CANCELLED_BY_PASSENGER') {
        setState(() {
          _rideStatus = 'IDLE';
          _currentRideId = null; _stopWatchingIncomingCall(); _deliveryPin = '';
          _showCancelButton = false;
        });
        _ticketListener?.cancel();
        _stopTrackingDriver();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This trip was cancelled.'),
          backgroundColor: Colors.red,
        ));
      } else if (currentStatus == 'COMPLETED') {
        _isRideCardMinimized = false;
        setState(() {
          _lastCompletedRideId = _currentRideId;
          _rideStatus = 'IDLE';
          _currentRideId = null; _stopWatchingIncomingCall(); _deliveryPin = '';
          _showCompletionPopup = true;
        });
        _ticketListener?.cancel();
        _stopTrackingDriver();
      }
    }
  });
  }

  Future<void> _restoreActiveRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app');
    final snap = await db.ref('rides').orderByChild('passengerId').equalTo(uid).limitToLast(5).get();
    if (!mounted || snap.value == null) return;
    final rides = snap.value as Map<dynamic, dynamic>;
    String? newestId;
    int newestTs = -1;
    for (final e in rides.entries) {
      final v = e.value;
      if (v is Map && (v['status'] == 'ACCEPTED' || (v['status'] == 'IN_PROGRESS' && v['type'] != 'delivery'))) {
        final ts = v['timestamp'] is num ? (v['timestamp'] as num).toInt() : 0;
        if (ts > newestTs) { newestTs = ts; newestId = e.key.toString(); }
      }
    }
    for (final entry in rides.entries) {
      final r = entry.value;
      if (r is! Map) continue;
      final id = entry.key.toString();
      if (r['status'] == 'PENDING') {
        db.ref('rides/$id').update({'status': 'CANCELLED_BY_PASSENGER'});
        continue;
      }
      if (r['status'] != 'ACCEPTED' && (r['status'] != 'IN_PROGRESS' || r['type'] == 'delivery')) continue;
      if (id != newestId) {
        db.ref('rides/$id').update({'status': 'CANCELLED_BY_PASSENGER'});
        continue;
      }
      setState(() {
        _currentRideId = id;
        _assignedDriverId = r['assignedDriverId']?.toString();
        _rideStatus = r['status'].toString();
        _showCancelButton = r['status'] == 'ACCEPTED';
        _deliveryPin = (r['deliveryPin'] ?? '').toString();
        _isSendMode = r['type'] == 'delivery';
        if (r['recipientPhone'] != null) _recipientPhoneCtrl.text = r['recipientPhone'].toString();
        if (r['dropoffLat'] != null && r['dropoffLng'] != null) {
          _dropoffLocation = LatLng((r['dropoffLat'] as num).toDouble(), (r['dropoffLng'] as num).toDouble());
          _dropoffText = (r['dropoffText'] ?? _dropoffText).toString();
        }
        _pickupText = (r['pickupText'] ?? _pickupText).toString();
      });
      _watchIncomingCall(id);
      _startTrackingDriver();
      _listenToRide(id);
    }
  }


  String _getDriverEtaBadge() {
    if (_driverLocation == null) return "Calculating ETA...";
    final target = _rideStatus == 'IN_PROGRESS'
        ? (_dropoffLocation ?? _myLocation)
        : (_customPickupLocation ?? _myLocation);
    final meters = Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      target.latitude,
      target.longitude,
    );
    if (meters < 100) return "Arriving now (<100m)";
    // Default 30 km/h (8.33 m/s) in town
    final totalSecs = (meters / 8.33).round();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final km = (meters / 1000).toStringAsFixed(1);
    if (mins <= 0) return "ETA ~${secs}s (${km} km)";
    return "ETA ~${mins}m ${secs}s (${km} km)";
  }

  void _startTrackingDriver() {
    if (_assignedDriverId == null) return;
    DatabaseReference driverRef = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app').ref('drivers/$_assignedDriverId');
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app')
    .ref('drivers/$_assignedDriverId/profile')
    .once()
    .then((snap) {
  final d = snap.snapshot.value as Map<dynamic, dynamic>?;
  if (d != null && mounted) {
    setState(() {
      _driverName = d['fullName'] ?? 'Driver';
      _driverPhone = d['phoneNumber'] ?? '';
      _driverPhoto = (d['profileImageUrl'] ?? d['photoUrl'])?.toString();
    });
  }
});
    _driverLocationListener = driverRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (data['latitude'] != null && data['longitude'] != null) {
          setState(() {
            _driverLocation = LatLng(data['latitude'], data['longitude']);
              _driverHeading = (data['heading'] as num?)?.toDouble() ?? _driverHeading;
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
    setState(() { _rideStatus = 'IDLE'; _showCancelButton = false; _cancelSecondsLeft = 120; });
    if (_currentRideId != null) {
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app').ref('rides/$_currentRideId').update({'status': 'CANCELLED_BY_PASSENGER'});
      _currentRideId = null; _stopWatchingIncomingCall(); _deliveryPin = '';
    }
    _stopTrackingDriver();
    _ticketListener?.cancel();
  }

  void _submitRating() async {
    if (_lastCompletedRideId != null && _givenRating > 0) {
      DatabaseReference rideRef = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app').ref('rides/$_lastCompletedRideId');
      await rideRef.update({'rating': _givenRating});
    }
    setState(() {
      _showCompletionPopup = false;
      _dropoffLocation = null;
      _estimatedFare = "K 0.00";
      _dropoffText = "Tap map to set dropoff..."; _isSendMode = false; _deliveryPin = ''; _recipientNameCtrl.clear(); _recipientPhoneCtrl.clear(); _parcelNoteCtrl.clear();
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
                onPickupDragged: (newPos) {
                  setState(() {
                    if (_inArea(newPos, 'Pickup')) { _customPickupLocation = newPos;
                    _pickupText = 'Adjusted Pickup'; }
                  });
                  _calculateFare();
                },
                dropoffLocation: _dropoffLocation,
                driverLocation: _driverLocation,
                driverHeading: _driverHeading,
                polylinePoints: _routePoints,
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
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_rideStatus == 'IDLE') ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _isPanelMinimized = !_isPanelMinimized),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(width: 24),
                                  Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_isPanelMinimized ? "Expand" : "Map", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                      Icon(_isPanelMinimized ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isPanelMinimized) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _dropoffLocation == null ? "Tap anywhere on map to set dropoff" : _dropoffText,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                                if (_dropoffLocation != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(_estimatedFare, style: TextStyle(color: flisingOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => setState(() => _isPanelMinimized = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: flisingOrange,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text("OPEN", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ] else ...[
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
                                  child: Icon(Icons.my_location, color: flisingOrange, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_pickupText, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.search, color: Colors.white54, size: 20),
                                  onPressed: () => _showLocationSearchSheet(true),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 12),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: _dropoffLocation != null ? flisingOrange : Colors.white54, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_dropoffText, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.search, color: Colors.white54, size: 20),
                                  onPressed: () => _showLocationSearchSheet(false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_dropoffLocation != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: flisingOrange.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.payments_outlined, color: flisingOrange, size: 16),
                                      const SizedBox(width: 6),
                                      const Text("Estimated Fare", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    ]),
                                    Text(_estimatedFare, style: TextStyle(color: flisingOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (_estimatedETA.isNotEmpty)
                                      Text('~$_estimatedETA', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(child: _modeOption(false, Icons.local_taxi, 'Ride')),
                                const SizedBox(width: 8),
                                Expanded(child: _modeOption(true, Icons.inventory_2, 'Send')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isSendMode) ...[
                              Row(
                                children: [
                                  Expanded(child: _sendField(_recipientNameCtrl, 'Recipient name', Icons.person_outline, TextInputType.name)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _sendField(_recipientPhoneCtrl, 'Phone number', Icons.phone_outlined, TextInputType.phone)),
                                ],
                              ),
                              _sendField(_parcelNoteCtrl, "What's in the parcel? (optional)", Icons.notes, TextInputType.text),
                            ],
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: _vehicleOption('car', Icons.directions_car, 'Car', _isSendMode ? 'K5.00/km' : 'K6.70/km')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _vehicleOption('motorcycle', Icons.two_wheeler, 'Motorcycle', _isSendMode ? 'K5.00/km' : 'K5.50/km')),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (_dropoffLocation != null) {
                                  if (_isSendMode && (_recipientNameCtrl.text.trim().isEmpty || _recipientPhoneCtrl.text.trim().length < 7)) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: const Text("Enter the recipient's name and phone number"),
                                      backgroundColor: flisingOrange,
                                    ));
                                  } else {
                                    _showPaymentSelection();
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: const Text('Set a dropoff location first'),
                                    backgroundColor: flisingOrange,
                                  ));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: flisingOrange,
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_isSendMode ? "REQUEST DELIVERY" : "REQUEST RIDE", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ],
                        if (_rideStatus == 'SEARCHING') ...[
                          const CircularProgressIndicator(color: Color(0xFFE9692C)),
                          const SizedBox(height: 20),
                          Text(_isSendMode ? "Finding a driver for your parcel..." : "Finding your premium ride...", style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                      onPressed: _cancelRide,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                      child: Text("CANCEL (${_cancelSecondsLeft}s)"),
                    ),
                        ],
                        
                        if (!_isRideCardMinimized && _deliveryPin.isNotEmpty && (_rideStatus == 'ACCEPTED' || _rideStatus == 'IN_PROGRESS'))
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: flisingOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: flisingOrange),
                            ),
                            child: Column(children: [
                              const Text('DELIVERY PIN', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(_deliveryPin, style: TextStyle(color: flisingOrange, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 10)),
                              const Text('Give this to the recipient. The driver needs it to finish.',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _textPinToRecipient,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white38),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.sms_outlined, color: Colors.white, size: 16),
                                      label: const Text('SMS PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _whatsappPinToRecipient,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.chat_outlined, color: Colors.white, size: 16),
                                      label: const Text('WHATSAPP PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ]),
                          ),

                        if (_rideStatus == 'ACCEPTED' || _rideStatus == 'IN_PROGRESS') ...[
                          InkWell(
                            onTap: () => setState(() => _isRideCardMinimized = !_isRideCardMinimized),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _rideStatus == 'IN_PROGRESS'
                                        ? (_deliveryPin.isNotEmpty ? "📦 PARCEL ON ITS WAY • ${_getDriverEtaBadge()}" : "🟢 TRIP IN PROGRESS • ${_getDriverEtaBadge()}")
                                        : (_deliveryPin.isNotEmpty ? "📦 DRIVER COMING • ${_getDriverEtaBadge()}" : "🚗 DRIVER ON THE WAY • ${_getDriverEtaBadge()}"),
                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isRideCardMinimized ? "EXPAND" : "MINIMIZE",
                                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _isRideCardMinimized ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isRideCardMinimized) ...[
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
   Expanded(child: Text(_driverFirstName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                              if (_rideStatus == 'ACCEPTED') ...[
                                if (_rideStatus == 'ACCEPTED') ...[
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble, color: Colors.white),
                                  onPressed: () {
                                    if (_currentRideId == null) return;
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        rideId: _currentRideId!,
                                        senderType: 'passenger',
                                        otherPersonName: _driverFirstName,
                                        otherPersonPhoto: _driverPhoto,
                                      ),
                                    ));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                                  onPressed: () {
                                    if (_currentRideId == null) return;
                                    _callScreenOpen = true;
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => CallScreen(
                                        rideId: _currentRideId!,
                                        callerType: 'passenger',
                                        otherPersonName: _driverFirstName,
                                        otherPersonPhoto: _driverPhoto,
                                      ),
                                    )).then((_) => _callScreenOpen = false);
                                  },
                                ),
                              ] else const Text("🔒 On Trip", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline, color: Colors.white54, size: 14),
                                      SizedBox(width: 4),
                                      Text("Calls locked on trip", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_showCancelButton) ElevatedButton(onPressed: _cancelRide, child: const Text("CANCEL RIDE")),
                          ],
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
                        Text(
                          _deliveryPin.isNotEmpty
                              ? "Parcel picked up! Rate your driver."
                              : "Thank you for choosing Flising.",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (_deliveryPin.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: flisingOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: flisingOrange),
                            ),
                            child: Column(
                              children: [
                                const Text('DELIVERY PIN FOR RECIPIENT', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(_deliveryPin, style: TextStyle(color: flisingOrange, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _textPinToRecipient,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white38),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                        ),
                                        icon: const Icon(Icons.sms_outlined, color: Colors.white, size: 15),
                                        label: const Text('SMS PIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _whatsappPinToRecipient,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF25D366),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                        ),
                                        icon: const Icon(Icons.chat_outlined, color: Colors.white, size: 15),
                                        label: const Text('WHATSAPP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
