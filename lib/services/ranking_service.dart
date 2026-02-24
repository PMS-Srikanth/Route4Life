import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import '../services/location_service.dart';

class RankingService {
  /// Rank hospitals by distance + availability.
  ///
  /// Priority order:
  ///   1. ICU + doctor + beds > 0  (ideal)
  ///   2. Doctor available (no ICU) — graceful fallback for highway accidents
  ///   3. Any open hospital — last resort
  static List<HospitalModel> rankHospitals({
    required List<HospitalModel> hospitals,
    required LatLng fromLocation,
    int topN = 3,
  }) {
    if (hospitals.isEmpty) return [];

    // Compute distance for every hospital first
    for (final h in hospitals) {
      h.distanceFromPatient = LocationService.distanceBetween(
        fromLocation,
        h.location,
      );
    }

    // Tier 1 — fully equipped
    var candidates = hospitals.where((h) {
      return h.icuAvailable && h.doctorAvailable && h.icuBeds > 0;
    }).toList();

    // Tier 2 — doctor available (not fully equipped)
    if (candidates.isEmpty) {
      candidates = hospitals.where((h) => h.doctorAvailable).toList();
    }

    // Tier 3 — anything (edge case: test/demo scenario)
    if (candidates.isEmpty) {
      candidates = List.of(hospitals);
    }

    // Sort by distance (ascending)
    candidates.sort(
      (a, b) => (a.distanceFromPatient ?? 0).compareTo(
        b.distanceFromPatient ?? 0,
      ),
    );

    return candidates.take(topN).toList();
  }

  /// Format a distance in metres to a human-readable string.
  /// Shows km for >= 1000 m, otherwise metres.
  static String formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }
}
