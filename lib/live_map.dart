import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveMap extends StatefulWidget {
  final LatLng myLocation;
  final LatLng? customPickupLocation;
  final LatLng? dropoffLocation;
  final LatLng? driverLocation;
  final double driverHeading;
  final List<LatLng> polylinePoints;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(LatLng) onTap;

  const LiveMap({
    super.key,
    required this.myLocation,
    this.customPickupLocation,
    this.dropoffLocation,
    this.driverLocation,
    this.driverHeading = 0,
    this.polylinePoints = const [],
    required this.onMapCreated,
    required this.onTap,
  });

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
  }

  Future<void> _loadCarIcon() async {
    _carIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(64, 64)),
      "assets/images/map_marker.png",
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};

    // 1. Pickup Marker (Green)
    LatLng activePickup = widget.customPickupLocation ?? widget.myLocation;
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: activePickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // 2. Dropoff Marker (Red)
    if (widget.dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // 3. Driver Marker (Orange)
    if (widget.driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driverLocation!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: widget.driverHeading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ),
      );
    }

    // 4. Route Polyline
    Set<Polyline> polylines = {};
    if (widget.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.polylinePoints,
          color: const Color(0xFFE9692C),
          width: 5,
        ),
      );
    }

    return GoogleMap(
      onMapCreated: widget.onMapCreated,
      initialCameraPosition: CameraPosition(
        target: widget.myLocation,
        zoom: 14.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      onTap: widget.onTap,
      markers: markers,
      polylines: polylines,
    );
  }
}
