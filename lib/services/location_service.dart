import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  static Stream<Position>? _positionStream;

  // ── Debug GPS override ───────────────────────────────────────────────────
  // Emulators default to Google HQ (Mountain View, CA).  To avoid the
  // 13 000 km distance bug during development, we start the GPS at the
  // centre of Vijayawada.  This override only applies in debug builds.
  // Remove / set to null before shipping the production build.
  static LatLng? _debugLocationOverride =
      kDebugMode ? const LatLng(16.5062, 80.6480) : null;

  /// In a real device session, call this with the actual GPS fix once
  /// the driver moves (the live stream will replace it automatically).
  // ignore: unused_element
  static void _clearDebugOverride() => _debugLocationOverride = null;
  // ─────────────────────────────────────────────────────────────────────────

  static Future<LatLng?> getCurrentLocation() async {
    // Always try real GPS first (works on real device)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 8));
          return LatLng(position.latitude, position.longitude);
        } catch (_) {
          // GPS timed out (emulator) — fall through to debug override
        }
      }
    }

    // Fallback: use debug override (emulator / GPS unavailable)
    return _debugLocationOverride;
  }

  static Stream<Position> getLiveLocationStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    );
    return _positionStream!;
  }

  static double distanceBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
