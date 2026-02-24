import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import 'distance_calculator.dart';

class HospitalSelector {
  /// From a list of hospitals (already ranked), pick the best one.
  /// Prefers accepted (confirmed) hospitals. Falls back to closest available.
  static HospitalModel? selectBest({
    required List<HospitalModel> hospitals,
    required LatLng patientLocation,
    List<String> acceptedHospitalIds = const [],
  }) {
    if (hospitals.isEmpty) return null;

    // Prefer hospitals that have been confirmed/accepted
    if (acceptedHospitalIds.isNotEmpty) {
      final confirmed = hospitals
          .where((h) => acceptedHospitalIds.contains(h.id))
          .toList();
      if (confirmed.isNotEmpty) {
        // Sort by distance
        confirmed.sort(
          (a, b) => DistanceCalculator.meters(patientLocation, a.location)
              .compareTo(
                  DistanceCalculator.meters(patientLocation, b.location)),
        );
        return confirmed.first;
      }
    }

    // Fall back to first in ranked list (already sorted by distance)
    return hospitals.first;
  }
}
