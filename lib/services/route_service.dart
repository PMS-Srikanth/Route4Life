import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../core/constants.dart';
import '../models/route_model.dart';

class RouteService {
  static final PolylinePoints _polylinePoints = PolylinePoints();

  /// Get a driving route between two points using Google Directions API.
  static Future<RouteModel?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination:
              PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) return null;

      final points = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      // Fetch distance/duration from Directions API
      final dirUrl =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&key=${AppConstants.googleMapsApiKey}';

      final resp = await http.get(Uri.parse(dirUrl));
      double distanceMeters = 0;
      int durationSeconds = 0;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final leg = data['routes']?[0]?['legs']?[0];
        distanceMeters =
            ((leg?['distance']?['value'] ?? 0) as num).toDouble();
        durationSeconds = (leg?['duration']?['value'] ?? 0) as int;
      }

      return RouteModel(
        polylinePoints: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      return null;
    }
  }
}
