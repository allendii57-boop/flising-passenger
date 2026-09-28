import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A town Flising operates in. The map, pickups and dropoffs
/// are locked to the active area's box.
class ServiceArea {
  final String id;
  final String name;
  final double south, west, north, east;

  const ServiceArea({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  bool contains(LatLng p) =>
      p.latitude >= south && p.latitude <= north &&
      p.longitude >= west && p.longitude <= east;

  LatLngBounds get bounds => LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );
}

/// Add new towns here. Vanimo runs from the Wutung border to just past town.
const Map<String, ServiceArea> serviceAreas = {
  'vanimo': ServiceArea(
    id: 'vanimo', name: 'Vanimo',
    south: -2.80, west: 141.00, north: -2.55, east: 141.40,
  ),
};

/// The active area. Later: chosen from GPS or the passenger's saved town.
ServiceArea currentServiceArea = serviceAreas['vanimo']!;
