import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineHelper {
  /// Builds a Set<Polyline> from a list of LatLng points.
  static Set<Polyline> buildPolylines(
    List<LatLng> points, {
    Color color = const Color(0xFFE53935),
    int width = 5,
    String id = 'route',
  }) {
    if (points.isEmpty) return {};

    return {
      Polyline(
        polylineId: PolylineId(id),
        color: color,
        width: width,
        points: points,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }
}
