import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/case_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import 'navigation_to_patient_screen.dart';
import 'nearby_hospitals_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Pre-filled with Vijayawada Railway Station for quick navigation test
  final _latController = TextEditingController(text: '16.518200');
  final _lngController = TextEditingController(text: '80.616800');
  final _patientNameController = TextEditingController();
  final _emergencyController = TextEditingController(text: 'Critical');
  bool _isGpsLoading = false;

  Future<void> _autoDetectGPS() async {
    setState(() => _isGpsLoading = true);
    final loc = await LocationService.getCurrentLocation();
    if (loc != null) {
      _latController.text = loc.latitude.toStringAsFixed(6);
      _lngController.text = loc.longitude.toStringAsFixed(6);
    }
    setState(() => _isGpsLoading = false);
  }

  void _startCase() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or auto-detect location')),
      );
      return;
    }

    final caseModel = CaseModel(
      caseId: DateTime.now().millisecondsSinceEpoch.toString(),
      patientName: _patientNameController.text.trim().isEmpty
          ? 'Unknown Patient'
          : _patientNameController.text.trim(),
      emergencyType: _emergencyController.text.trim(),
      patientLocation: LatLng(lat, lng),
      dispatchedBy: '108 Control',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationToPatientScreen(caseModel: caseModel),
      ),
    );
  }

  /// Directly launch Google Maps navigation to the entered coordinates,
  /// without creating a full case — quickest path to the patient.
  Future<void> _quickNavigate() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter / auto-detect patient location first')),
      );
      return;
    }

    await NavigationService.navigateTo(
      LatLng(lat, lng),
      label: _patientNameController.text.trim().isEmpty
          ? 'Patient'
          : _patientNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = AuthService.currentDriver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route4Life'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver info
            Card(
              color: const Color(0xFFFFEBEE),
              child: ListTile(
                leading: const Icon(Icons.person, color: Color(0xFFE53935)),
                title: Text(driver?.name ?? 'Driver'),
                subtitle: Text('Vehicle: ${driver?.vehicleNumber ?? '-'}'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'New Case',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _patientNameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name (optional)',
                prefixIcon: Icon(Icons.personal_injury),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyController,
              decoration: const InputDecoration(
                labelText: 'Emergency Type',
                prefixIcon: Icon(Icons.warning_amber),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isGpsLoading ? null : _autoDetectGPS,
              icon: _isGpsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Auto-detect GPS'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startCase,
                icon: const Icon(Icons.medical_services, color: Colors.white),
                label: const Text(
                  'Start Case & Track Route',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Quick Google Maps navigation (no case creation needed) ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _quickNavigate,
                icon: const Icon(Icons.navigation, color: Colors.white),
                label: const Text(
                  'Quick Navigate (Google Maps)',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final loc = await LocationService.getCurrentLocation();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NearbyHospitalsScreen(
                        initialLocation: loc,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.local_hospital,
                    color: Color(0xFFE53935)),
                label: const Text(
                  'View Nearby Hospitals',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE53935), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
