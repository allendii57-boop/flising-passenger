import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveMap extends StatelessWidget {
  final LatLng myLocation;
  final LatLng? customPickupLocation;
  final LatLng? dropoffLocation;
  final LatLng? driverLocation;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(LatLng) onTap;

  const LiveMap({
    super.key,
    required this.myLocation,
    this.customPickupLocation,
    this.dropoffLocation,
    this.driverLocation,
    required this.onMapCreated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};

    // 1. Pickup Marker (Green)
    LatLng activePickup = customPickupLocation ?? myLocation;
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: activePickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // 2. Dropoff Marker (Red)
    if (dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // 3. Driver Marker (Orange)
    if (driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: myLocation,
        zoom: 14.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      onTap: onTap,
      markers: markers,
    );
  }
}
