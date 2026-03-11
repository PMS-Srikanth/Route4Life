class AppThresholds {
  /// Distance in meters to trigger re-ranking when approaching patient.
  static const double nearPatientRadius = 500.0;

  /// Distance in meters considered "at patient location" (pickup zone).
  static const double pickupRadius = 50.0;

  /// Max radius in meters to search for hospitals initially.
  static const double initialHospitalSearchRadius = 10000.0; // 10 km

  /// Max radius in meters to re-search hospitals near patient.
  static const double nearPatientHospitalSearchRadius = 7000.0; // 7 km
}
