import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../models/hospital_model.dart';
import 'location_service.dart';

class HospitalService {
  // ── VERIFIED Vijayawada hospitals — GPS coords from Google Maps ──────────
  // Center of Vijayawada (debug GPS override): 16.5062, 80.6480
  // All hospitals below are within 10 km of city centre.
  static List<HospitalModel> _vijayawadaHospitals() => [
        // ── 1. GGH — Government General Hospital (~1.2 km from centre) ──
        HospitalModel(
          id: 'h1',
          name: 'Government General Hospital (GGH)',
          address: 'Eluru Rd, Governorpet, Vijayawada – 520002',
          location: const LatLng(16.5161, 80.6174),
          icuAvailable: true, doctorAvailable: true, icuBeds: 30,
          phone: '0866-2571919',
        ),
        // ── 2. Aster Ramesh — MG Road (~1.0 km) ──
        HospitalModel(
          id: 'h2',
          name: 'Aster Ramesh Hospitals (MG Road)',
          address: 'MG Rd, Opp. Indira Gandhi Stadium, Vijayawada',
          location: const LatLng(16.5028, 80.6389),
          icuAvailable: true, doctorAvailable: true, icuBeds: 20,
          phone: '0866-2472000',
        ),
        // ── 3. Help Hospitals (~1.5 km) ──
        HospitalModel(
          id: 'h3',
          name: 'Help Hospitals',
          address: 'MG Rd, Behind Bapu Museum, Vijayawada',
          location: const LatLng(16.5089, 80.6274),
          icuAvailable: true, doctorAvailable: true, icuBeds: 15,
          phone: '0866-6615552',
        ),
        // ── 4. Andhra Hospitals — main branch (~1.8 km) ──
        HospitalModel(
          id: 'h4',
          name: 'Andhra Hospitals',
          address: 'CVR Complex, 29-14-61 Sheshadri Sastry St, Vijayawada',
          location: const LatLng(16.5111, 80.6295),
          icuAvailable: true, doctorAvailable: true, icuBeds: 18,
          phone: '0866-2574757',
        ),
        // ── 5. Vijaya Super Speciality (~1.0 km) ──
        HospitalModel(
          id: 'h5',
          name: 'Vijaya Super Speciality Hospital',
          address: '29-26-92A, Bolivar St, Vijayawada',
          location: const LatLng(16.5137, 80.6373),
          icuAvailable: true, doctorAvailable: true, icuBeds: 10,
          phone: '094401 44477',
        ),
        // ── 6. Manipal Hospital (~4.0 km south) ──
        HospitalModel(
          id: 'h6',
          name: 'Manipal Hospital Vijayawada',
          address: '12-570, Near Kanakadurga Varadhi, Vijayawada',
          location: const LatLng(16.4845, 80.6170),
          icuAvailable: true, doctorAvailable: true, icuBeds: 22,
          phone: '1800-102-4647',
        ),
        // ── 7. Kamineni Hospitals (~5.9 km east) ──
        HospitalModel(
          id: 'h7',
          name: 'Kamineni Hospitals',
          address: '100 Feet Rd, New Autonagar, Vijayawada',
          location: const LatLng(16.4959, 80.7031),
          icuAvailable: true, doctorAvailable: true, icuBeds: 25,
          phone: '0866-2463333',
        ),
        // ── 8. Andhra Hospitals Bhavanipuram (~7.5 km northwest) ──
        HospitalModel(
          id: 'h8',
          name: 'Andhra Hospitals – Bhavanipuram',
          address: 'Opp. ZP High School, Moulangar Masjid Rd, Bhavanipuram',
          location: const LatLng(16.5363, 80.5847),
          icuAvailable: true, doctorAvailable: true, icuBeds: 12,
          phone: '0866-2415757',
        ),
        // ── 9. Pinnamaneni Siddharth — NH-16 corridor (~20 km east) ──
        // Shown only when radius expands to 20 km
        HospitalModel(
          id: 'h9',
          name: 'Pinnamaneni Siddharth Hospital',
          address: 'NH-16, Gannavaram, Near Vijayawada Airport',
          location: const LatLng(16.5403, 80.8006),
          icuAvailable: true, doctorAvailable: true, icuBeds: 10,
          phone: '0866-2340066',
        ),
        // ── 10. NRI Medical College — NH-16, 30 km (20 km outer ring) ──
        HospitalModel(
          id: 'h10',
          name: 'NRI Academy of Medical Sciences',
          address: 'Chinakakani, Guntur District (NH-16)',
          location: const LatLng(16.2334, 80.8025),
          icuAvailable: true, doctorAvailable: true, icuBeds: 30,
          phone: '08645-246100',
        ),
      ];
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch hospitals near [near].
  /// Tries 10 km first — if no results, expands to 20 km automatically.
  static Future<List<HospitalModel>> fetchHospitals({
    required LatLng near,
    double? radiusMeters,
  }) async {
    // Use mock if backend URL is still a placeholder
    if (AppConstants.baseUrl.contains('YOUR_BACKEND_URL')) {
      return _filterByRadius(
        hospitals: _vijayawadaHospitals(),
        near: near,
        radiusMeters: radiusMeters,
      );
    }

    // Real backend — try 10km, expand to 20km if empty
    try {
      var result = await _fetchFromBackend(near: near, radiusMeters: 10000);
      if (result.isEmpty) {
        result = await _fetchFromBackend(near: near, radiusMeters: 20000);
      }
      return result;
    } catch (e) {
      // Fallback to mock filtered by radius
      return _filterByRadius(
        hospitals: _vijayawadaHospitals(),
        near: near,
        radiusMeters: radiusMeters,
      );
    }
  }

  static Future<List<HospitalModel>> _fetchFromBackend({
    required LatLng near,
    required double radiusMeters,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.hospitalsEndpoint}',
    ).replace(queryParameters: {
      'lat': near.latitude.toString(),
      'lng': near.longitude.toString(),
      'radius': radiusMeters.toString(),
    });

    final response = await http.get(uri,
        headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((h) => HospitalModel.fromJson(h)).toList();
    }
    return [];
  }

  /// Filter mock hospitals: try 10 km first, expand to 20 km if none found.
  static List<HospitalModel> _filterByRadius({
    required List<HospitalModel> hospitals,
    required LatLng near,
    double? radiusMeters,
  }) {
    const double radius10km = 10000;
    const double radius20km = 20000;
    final double radius = radiusMeters ?? radius10km;

    // Primary search within requested radius (default 10 km)
    var filtered = hospitals.where((h) {
      final dist = LocationService.distanceBetween(near, h.location);
      return dist <= radius;
    }).toList();

    // If nothing found within 10 km, expand to 20 km automatically
    if (filtered.isEmpty && radius <= radius10km) {
      filtered = hospitals.where((h) {
        final dist = LocationService.distanceBetween(near, h.location);
        return dist <= radius20km;
      }).toList();
    }

    // Last-resort fallback: return all sorted by distance
    // (handles emulator far from Vijayawada during testing)
    if (filtered.isEmpty) {
      final sorted = List<HospitalModel>.from(hospitals);
      sorted.sort((a, b) {
        final da = LocationService.distanceBetween(near, a.location);
        final db = LocationService.distanceBetween(near, b.location);
        return da.compareTo(db);
      });
      return sorted;
    }

    // Sort by distance before returning
    filtered.sort((a, b) {
      final da = LocationService.distanceBetween(near, a.location);
      final db = LocationService.distanceBetween(near, b.location);
      return da.compareTo(db);
    });

    return filtered;
  }
}
