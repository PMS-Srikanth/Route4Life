import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import '../models/request_model.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../services/ranking_service.dart';
import '../services/request_service.dart';
import '../services/navigation_service.dart';
import '../widgets/hospital_card.dart';
import 'dashboard_screen.dart';

class NearbyHospitalsScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const NearbyHospitalsScreen({super.key, this.initialLocation});

  @override
  State<NearbyHospitalsScreen> createState() => _NearbyHospitalsScreenState();
}

class _NearbyHospitalsScreenState extends State<NearbyHospitalsScreen> {
  List<HospitalModel> _hospitals = [];
  bool _loading = true;
  String? _error;
  LatLng? _searchLocation;
  double _usedRadius = 10000;
  final Set<String> _requestingIds = {};
  // hospitalId → requestId
  final Map<String, String> _requestIds = {};
  // hospitalId → status: 'pending' | 'accepted' | 'rejected'
  final Map<String, String> _requestStatus = {};
  // hospitalId → polling timer
  final Map<String, Timer> _pollTimers = {};

  @override
  void dispose() {
    for (final t in _pollTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load(widget.initialLocation);
  }

  Future<void> _load(LatLng? location) async {
    setState(() { _loading = true; _error = null; });

    LatLng? loc = location ?? await LocationService.getCurrentLocation();

    if (loc == null) {
      setState(() {
        _error = 'Could not get location. Please try again.';
        _loading = false;
      });
      return;
    }

    _searchLocation = loc;

    // Try 10km first
    var hospitals = await HospitalService.fetchHospitals(
      near: loc,
      radiusMeters: 10000,
    );

    double usedRadius = 10000;

    // Expand to 20km if none found (highway scenario)
    if (hospitals.isEmpty) {
      hospitals = await HospitalService.fetchHospitals(
        near: loc,
        radiusMeters: 20000,
      );
      usedRadius = 20000;
    }

    final ranked = RankingService.rankHospitals(
      hospitals: hospitals,
      fromLocation: loc,
      topN: hospitals.length, // show all, not just top 3
    );

    setState(() {
      _hospitals = ranked;
      _usedRadius = usedRadius;
      _loading = false;
    });
  }

  void _startPolling(String hospitalId, String requestId, String hospitalName) {
    _pollTimers[hospitalId]?.cancel();
    int attempts = 0;
    const maxAttempts = 24; // 24 × 5s = 2 minutes

    _pollTimers[hospitalId] = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        attempts++;
        if (attempts > maxAttempts) {
          timer.cancel();
          if (mounted) setState(() => _requestStatus.remove(hospitalId));
          return;
        }
        final status = await RequestService.checkRequestStatus(requestId);
        if (!mounted) { timer.cancel(); return; }
        if (status == RequestStatus.accepted || status == RequestStatus.rejected) {
          timer.cancel();
          setState(() => _requestStatus[hospitalId] = status.name);

          if (status == RequestStatus.accepted) {
            // Find the hospital model so we can navigate to it
            final hospital = _hospitals.firstWhere(
              (h) => h.id == hospitalId,
              orElse: () => _hospitals.first,
            );

            // Show snackbar, then auto-launch Google Maps to hospital
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $hospitalName ACCEPTED! Opening navigation…'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            // Small delay so the snackbar is visible before Maps opens
            // Use patient pickup location as origin → hospital as destination
            Future.delayed(const Duration(seconds: 2), () {
              NavigationService.navigateTo(
                hospital.location,
                origin: _searchLocation,  // patient pickup point
                label: hospitalName,
              );
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '❌ $hospitalName REJECTED. Try the next hospital.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2 · Find Hospital'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(null),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _load(null),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Radius info banner
                    Container(
                      width: double.infinity,
                      color: _usedRadius > 10000
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE8F5E9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _usedRadius > 10000
                                ? Icons.warning_amber
                                : Icons.location_on,
                            color: _usedRadius > 10000
                                ? Colors.orange
                                : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _usedRadius > 10000
                                  ? 'No hospitals within 10 km — showing hospitals within 20 km (highway mode)'
                                  : 'Showing ${_hospitals.length} hospital${_hospitals.length == 1 ? '' : 's'} within 10 km',
                              style: TextStyle(
                                color: _usedRadius > 10000
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location info
                    if (_searchLocation != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Near ${_searchLocation!.latitude.toStringAsFixed(4)}, '
                              '${_searchLocation!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Hospital list
                    Expanded(
                      child: _hospitals.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_hospital_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text('No hospitals found nearby',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: _hospitals.length,
                              itemBuilder: (_, i) {
                                final h = _hospitals[i];
                                final isSending = _requestingIds.contains(h.id);
                                final status = _requestStatus[h.id];
                                final distKm = h.distanceFromPatient != null
                                    ? h.distanceFromPatient! / 1000
                                    : null;
                                return Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        HospitalCard(
                                          hospital: h,
                                          isSelected: i == 0,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              6, 0, 6, 4),
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: status == 'accepted'
                                                  ? Colors.green
                                                  : status == 'rejected'
                                                      ? Colors.grey
                                                      : const Color(0xFFE53935),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 10),
                                            ),
                                            icon: isSending
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Icon(
                                                    status == 'accepted'
                                                        ? Icons.check_circle
                                                        : status == 'rejected'
                                                            ? Icons.cancel
                                                            : Icons.send,
                                                    size: 16),
                                            label: Text(isSending
                                                ? 'Sending…'
                                                : status == 'accepted'
                                                    ? 'Accepted by Hospital ✅'
                                                    : status == 'rejected'
                                                        ? 'Rejected — Try Another'
                                                        : status == 'pending'
                                                            ? 'Waiting for Response…'
                                                            : 'Request Doctor Availability'),
                                            onPressed: (isSending ||
                                                    status == 'accepted' ||
                                                    status == 'pending')
                                                ? null
                                                : () async {
                                                    setState(() {
                                                      _requestingIds.add(h.id);
                                                      _requestStatus
                                                          .remove(h.id);
                                                    });
                                                    final reqId =
                                                        await RequestService
                                                            .sendRequest(
                                                      hospitalId: h.id,
                                                      emergencyType: 'Critical',
                                                      distanceKm: distKm,
                                                    );
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _requestingIds.remove(h.id);
                                                    });
                                                    final isError = reqId == null || (reqId.startsWith('ERR:'));
                                                    if (!isError) {
                                                      setState(() {
                                                        _requestIds[h.id] =
                                                            reqId!;
                                                        _requestStatus[h.id] =
                                                            'pending';
                                                      });
                                                      _startPolling(h.id, reqId!,
                                                          h.name);
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              '📧 Request sent to ${h.name} — waiting for response…'),
                                                          backgroundColor:
                                                              Colors.blue
                                                                  .shade700,
                                                          duration:
                                                              const Duration(
                                                                  seconds: 3),
                                                        ),
                                                      );
                                                    } else {
                                                      final detail = reqId ?? 'No response';
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              '❌ Failed: $detail. Is the server running?'),
                                                          backgroundColor:
                                                              Colors.red,
                                                          duration: const Duration(seconds: 6),
                                                        ),
                                                      );
                                                    }
                                                  },
                                          ),
                                        ),
                                        // ── Navigate button (shown when accepted) ──
                                        if (status == 'accepted')
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 6, 6),
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                  Icons.navigation,
                                                  size: 16,
                                                  color: Colors.white),
                                              label: const Text(
                                                'Navigate to Hospital (Google Maps)',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1976D2),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10),
                                              ),
                                              onPressed: () =>
                                                  NavigationService.navigateTo(
                                                h.location,
                                                origin: _searchLocation,  // patient pickup point
                                                label: h.name,
                                              ),
                                            ),
                                          ),
                                        // ── Arrived at Hospital → End Case ──
                                        if (status == 'accepted')
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 6, 10),
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                  Icons.local_hospital,
                                                  size: 16,
                                                  color: Colors.white),
                                              label: const Text(
                                                'Arrived at Hospital ✓ – End Case',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF388E3C),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10),
                                              ),
                                              onPressed: () {
                                                // Clear entire navigation stack → Dashboard
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const DashboardScreen(),
                                                  ),
                                                  (route) => false,
                                                );
                                              },
                                            ),
                                          ),
                                        // Status chip — shown while polling
                                        if (status == 'pending')
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 0, 12, 10),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFFE53935),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Waiting for hospital response…',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey
                                                          .shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    // Rank badge
                                    Positioned(
                                      top: 12,
                                      right: 18,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: i == 0
                                              ? const Color(0xFFE53935)
                                              : Colors.grey.shade400,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '#${i + 1}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
