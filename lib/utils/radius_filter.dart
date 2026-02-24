import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import 'distance_calculator.dart';

class RadiusFilter {
  /// Filters hospitals within [radiusMeters] of [center].
  static List<HospitalModel> filter({
    required List<HospitalModel> hospitals,
    required LatLng center,
    required double radiusMeters,
  }) {
    return hospitals.where((h) {
      return DistanceCalculator.isWithin(center, h.location, radiusMeters);
    }).toList();
  }
}
