import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DistanceCalculator {
  /// Returns distance in meters between two LatLng points.
  static double meters(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Returns true if distance is within [thresholdMeters].
  static bool isWithin(LatLng from, LatLng to, double thresholdMeters) {
    return meters(from, to) <= thresholdMeters;
  }
}
