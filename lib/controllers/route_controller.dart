import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

class RouteController extends ChangeNotifier {
  RouteModel? currentRoute;
  bool isLoading = false;
  String? error;

  Future<void> loadRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    currentRoute = await RouteService.getRoute(
      origin: origin,
      destination: destination,
    );

    if (currentRoute == null) {
      error = 'Could not fetch route';
    }

    isLoading = false;
    notifyListeners();
  }

  void clearRoute() {
    currentRoute = null;
    notifyListeners();
  }
}
