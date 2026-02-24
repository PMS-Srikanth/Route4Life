import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/case_controller.dart';
import '../controllers/route_controller.dart';
import '../services/location_service.dart';
import '../utils/polyline_helper.dart';
import 'case_complete_screen.dart';

/// After patient is on board and hospital is locked.
/// Only traffic-based route updates. No hospital switching.
class NavigationToHospitalScreen extends StatefulWidget {
  final CaseController caseController;
  const NavigationToHospitalScreen({super.key, required this.caseController});

  @override
  State<NavigationToHospitalScreen> createState() =>
      _NavigationToHospitalScreenState();
}

class _NavigationToHospitalScreenState
    extends State<NavigationToHospitalScreen> {
  final RouteController _routeController = RouteController();
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final driverLoc = await LocationService.getCurrentLocation();
    final hospital = widget.caseController.assignedHospital;
    if (driverLoc == null || hospital == null) return;

    await _routeController.loadRoute(
      origin: driverLoc,
      destination: hospital.location,
    );

    if (_routeController.currentRoute != null) {
      setState(() {
        _polylines = PolylineHelper.buildPolylines(
          _routeController.currentRoute!.polylinePoints,
        );
        _markers = {
          Marker(
            markerId: const MarkerId('driver'),
            position: driverLoc,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'You'),
          ),
          Marker(
            markerId: const MarkerId('hospital'),
            position: hospital.location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: hospital.name),
          ),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = widget.caseController.assignedHospital;

    return Scaffold(
      appBar: AppBar(
        title: const Text('To Hospital'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  hospital?.location ?? const LatLng(0, 0),
              zoom: 14,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 8)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital,
                          color: Color(0xFF388E3C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hospital?.name ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LOCKED',
                          style: TextStyle(
                              color: Color(0xFF388E3C),
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (hospital != null)
                    Text(hospital.address,
                        style: const TextStyle(color: Colors.grey)),
                  if (_routeController.currentRoute != null)
                    Text(
                      '${_routeController.currentRoute!.distanceText} · ${_routeController.currentRoute!.durationText}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.caseController.completeCase();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CaseCompleteScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Mark as Arrived at Hospital',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
