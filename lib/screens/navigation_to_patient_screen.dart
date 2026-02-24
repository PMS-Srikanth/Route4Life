import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/case_model.dart';
import '../controllers/case_controller.dart';
import '../controllers/route_controller.dart';
import '../utils/polyline_helper.dart';
import '../services/navigation_service.dart';
import 'pickup_threshold_screen.dart';
import 'nearby_hospitals_screen.dart';

class NavigationToPatientScreen extends StatefulWidget {
  final CaseModel caseModel;
  const NavigationToPatientScreen({super.key, required this.caseModel});

  @override
  State<NavigationToPatientScreen> createState() =>
      _NavigationToPatientScreenState();
}

class _NavigationToPatientScreenState
    extends State<NavigationToPatientScreen> {
  final CaseController _caseController = CaseController();
  final RouteController _routeController = RouteController();
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _caseController.setCase(widget.caseModel);
    _caseController.addListener(_onStateChange);
    _init();
    // Auto-launch Google Maps navigation to patient as soon as screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.navigateTo(
        widget.caseModel.patientLocation,
        label: widget.caseModel.patientName,
      );
    });
  }

  Future<void> _init() async {
    final driverLoc = await _getDriverLocation();
    if (driverLoc == null) return;

    await _routeController.loadRoute(
      origin: driverLoc,
      destination: widget.caseModel.patientLocation,
    );

    _updateMap(driverLoc);
  }

  Future<LatLng?> _getDriverLocation() async {
    return _caseController.driverLocation;
  }

  void _onStateChange() {
    if (_caseController.appState.index >= 1 &&
        _caseController.driverLocation != null) {
      _updateMap(_caseController.driverLocation!);
    }

    // Near patient — go to pickup threshold screen
    if (_caseController.appState.name == 'nearPatient' && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PickupThresholdScreen(
            caseController: _caseController,
          ),
        ),
      );
    }
  }

  void _updateMap(LatLng driverLoc) {
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
            markerId: const MarkerId('patient'),
            position: widget.caseModel.patientLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
                title: widget.caseModel.patientName),
          ),
        };
      });
    }
  }

  @override
  void dispose() {
    _caseController.removeListener(_onStateChange);
    _caseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 · Navigate to Patient'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.caseModel.patientLocation,
              zoom: 14,
            ),
            onMapCreated: (c) => _mapController = c,
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // Info + action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 8)
                ],
              ),
              child: ListenableBuilder(
                listenable: _caseController,
                builder: (_, __) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient info row
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFFE53935)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.caseModel.patientName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  'Emergency: ${widget.caseModel.emergencyType}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (_routeController.currentRoute != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_routeController.currentRoute!.distanceText}'
                                ' · ${_routeController.currentRoute!.durationText}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Google Maps Navigation button ──
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation, color: Colors.white),
                          label: const Text(
                            'Reopen Navigation to Patient',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => NavigationService.navigateTo(
                            widget.caseModel.patientLocation,
                            label: widget.caseModel.patientName,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Find Hospital / I have the patient ──
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.local_hospital,
                              color: Color(0xFF388E3C)),
                          label: const Text(
                            'Patient Boarded → Step 2: Find Hospital',
                            style: TextStyle(
                                color: Color(0xFF388E3C),
                                fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF388E3C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NearbyHospitalsScreen(
                                  initialLocation:
                                      widget.caseModel.patientLocation,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
