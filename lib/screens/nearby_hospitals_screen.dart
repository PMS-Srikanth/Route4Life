import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import '../models/request_model.dart';
import '../models/vitals_model.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../services/ranking_service.dart';
import '../services/request_service.dart';
import '../services/navigation_service.dart';
import '../widgets/hospital_card.dart';
import 'dashboard_screen.dart';

class NearbyHospitalsScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final VitalsModel? vitals;

  const NearbyHospitalsScreen({super.key, this.initialLocation, this.vitals});

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

  // Hospital arrival geo-fence
  StreamSubscription<Position>? _hospitalPositionSub;
  String? _monitoredHospitalId;
  bool _hospitalArrivalDialogShown = false;
  double _distanceToHospitalM = double.infinity;

  // Smart re-routing: track active destination + auto-requested hospitals
  String? _activeHospitalId;          // hospital we're currently en-route to
  final Set<String> _autoRequestedIds = {}; // auto-sent after acceptance

  // Live vitals streaming
  Timer? _vitalsUpdateTimer;
  VitalsModel? _currentVitals;
  bool _autoSendingInitial = false;

  @override
  void dispose() {
    for (final t in _pollTimers.values) {
      t.cancel();
    }
    _hospitalPositionSub?.cancel();
    _vitalsUpdateTimer?.cancel();
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
    // Auto-send to top 2 hospitals immediately on load
    if (ranked.isNotEmpty) {
      _autoSendInitialRequests();
    }
  }

  // ── Auto-send to the top 2 ranked hospitals immediately on screen load ──
  Future<void> _autoSendInitialRequests() async {
    if (!mounted || _hospitals.isEmpty) return;
    setState(() => _autoSendingInitial = true);
    final topCount = _hospitals.length < 2 ? _hospitals.length : 2;
    for (int i = 0; i < topCount; i++) {
      final h = _hospitals[i];
      if (_autoRequestedIds.contains(h.id) || _requestIds.containsKey(h.id)) continue;
      _autoRequestedIds.add(h.id);
      if (mounted) setState(() => _requestStatus[h.id] = 'pending');
      final distKm = h.distanceFromPatient != null ? h.distanceFromPatient! / 1000 : null;
      final reqId = await RequestService.sendRequest(
        hospitalId: h.id,
        emergencyType: 'Critical',
        distanceKm: distKm,
        vitals: widget.vitals,
      );
      if (!mounted) return;
      if (reqId != null && !reqId.startsWith('ERR:')) {
        setState(() => _requestIds[h.id] = reqId);
        // Hospital #1 (rank 1, index 0) = primary; hospital #2 = escalation backup
        _startPolling(h.id, reqId, h.name, isAutoEscalation: i > 0);
      } else {
        setState(() {
          _requestStatus.remove(h.id);
          _autoRequestedIds.remove(h.id);
        });
      }
    }
    if (mounted) {
      setState(() => _autoSendingInitial = false);
      if (widget.vitals != null && widget.vitals!.hasVitals && _requestIds.isNotEmpty) {
        _currentVitals = widget.vitals!;
        _startVitalsUpdater();
      }
    }
  }

  // ── Continuously vary and push vitals to all active requests every 20 s ──
  void _startVitalsUpdater() {
    _vitalsUpdateTimer?.cancel();
    _vitalsUpdateTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _currentVitals == null) return;
      _currentVitals = _varyVitals(_currentVitals!);
      for (final entry in _requestIds.entries) {
        final st = _requestStatus[entry.key];
        if (st == 'pending' || st == 'accepted') {
          await RequestService.pushVitals(entry.value, _currentVitals!);
        }
      }
    });
  }

  // ── Simulate realistic vital-sign drift (small random perturbations) ──
  VitalsModel _varyVitals(VitalsModel base) {
    final rng = Random();
    int? bpSys, bpDia;
    if (base.bloodPressure != null) {
      final parts = base.bloodPressure!.split('/');
      if (parts.length == 2) {
        bpSys = int.tryParse(parts[0].trim());
        bpDia = int.tryParse(parts[1].trim());
      }
    }
    final newBp = (bpSys != null && bpDia != null)
        ? '${(bpSys + rng.nextInt(11) - 5).clamp(60, 220)}'
            '/${(bpDia + rng.nextInt(7) - 3).clamp(40, 140)}'
        : base.bloodPressure;
    return VitalsModel(
      heartRate: base.heartRate == null
          ? null
          : (base.heartRate! + rng.nextInt(7) - 3).clamp(30, 250),
      bloodPressure: newBp,
      spo2: base.spo2 == null
          ? null
          : (base.spo2! + rng.nextInt(3) - 1).clamp(50, 100),
      consciousness: base.consciousness,
      conditionNotes: base.conditionNotes,
      audioFilePath: base.audioFilePath,
    );
  }

  void _startPolling(
    String hospitalId,
    String requestId,
    String hospitalName, {
    bool isAutoEscalation = false,
  }) {
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
            final hospital = _hospitals.firstWhere(
              (h) => h.id == hospitalId,
              orElse: () => _hospitals.first,
            );

            if (isAutoEscalation) {
              // ── Closer hospital accepted while en-route ──
              // Switch only if driver hasn't already arrived at the old destination
              _switchToHospital(hospital);
            } else {
              // ── Manual request accepted (initial selection) ──
              setState(() => _activeHospitalId = hospitalId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ $hospitalName ACCEPTED! Opening navigation…'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 2), () {
                NavigationService.navigateTo(
                  hospital.location,
                  origin: _searchLocation,
                  label: hospitalName,
                );
              });
              _startHospitalArrivalWatch(hospital);
              // Auto-request all better-ranked hospitals in background
              _autoRequestBetterRankedHospitals(hospital);
            }
          } else {
            if (isAutoEscalation) {
              // Silently remove — auto-request rejected, no need to tell driver
              setState(() {
                _requestStatus.remove(hospitalId);
                _autoRequestedIds.remove(hospitalId);
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ $hospitalName REJECTED. Try another hospital.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        }
      },
    );
  }

  // ── Geo-fence: watch position and auto-prompt when near hospital ──
  void _startHospitalArrivalWatch(HospitalModel hospital) {
    _hospitalPositionSub?.cancel();
    _monitoredHospitalId = hospital.id;
    _hospitalArrivalDialogShown = false;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
    _hospitalPositionSub =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen((pos) {
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        hospital.location.latitude,
        hospital.location.longitude,
      );
      if (mounted) setState(() => _distanceToHospitalM = dist);
      if (dist < 150 && !_hospitalArrivalDialogShown && mounted) {
        _hospitalArrivalDialogShown = true;
        _hospitalPositionSub?.cancel();
        _showHospitalArrivalDialog(hospital.name);
      }
    });
  }

  Future<void> _showHospitalArrivalDialog(String hospitalName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_hospital, color: Color(0xFF388E3C)),
            SizedBox(width: 8),
            Text('Arrived at Hospital?'),
          ],
        ),
        content: Text(
          'You are within 150 m of $hospitalName.\n\nConfirm arrival to end this case.'),
        actions: [
          TextButton(
            onPressed: () {
              _hospitalArrivalDialogShown = false;
              Navigator.pop(context, false);
            },
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, End Case ✓',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  // ── Auto-request all hospitals BETTER RANKED than the accepted one ──
  // Sends to hospitals at lower list indices (higher rank) automatically.
  Future<void> _autoRequestBetterRankedHospitals(HospitalModel current) async {
    final currentIndex = _hospitals.indexWhere((h) => h.id == current.id);
    if (currentIndex <= 0) return; // already best-ranked, nothing to check

    for (int i = 0; i < currentIndex; i++) {
      final h = _hospitals[i];
      if (_requestIds.containsKey(h.id)) continue;    // already requested
      if (_autoRequestedIds.contains(h.id)) continue; // already auto-sent

      _autoRequestedIds.add(h.id);
      if (mounted) setState(() => _requestStatus[h.id] = 'pending');

      final distKm = h.distanceFromPatient != null
          ? h.distanceFromPatient! / 1000
          : null;
      final reqId = await RequestService.sendRequest(
        hospitalId: h.id,
        emergencyType: 'Critical',
        distanceKm: distKm,
        vitals: widget.vitals,
      );
      if (!mounted) return;

      if (reqId != null && !reqId.startsWith('ERR:')) {
        setState(() => _requestIds[h.id] = reqId);
        _startPolling(h.id, reqId, h.name, isAutoEscalation: true);
      } else {
        setState(() {
          _requestStatus.remove(h.id);
          _autoRequestedIds.remove(h.id);
        });
      }
    }
  }

  // ── Switch active destination to a closer hospital ──
  void _switchToHospital(HospitalModel newHospital) {
    if (!mounted) return;
    // Don't switch if driver already within arrival threshold
    if (_distanceToHospitalM < 150) return;

    _hospitalPositionSub?.cancel();
    _hospitalArrivalDialogShown = false;

    setState(() => _activeHospitalId = newHospital.id);

    final oldHospital = _hospitals.firstWhere(
      (h) => h.id != newHospital.id && _requestStatus[h.id] == 'accepted',
      orElse: () => newHospital,
    );
    final savedKm = ((oldHospital.distanceFromPatient ?? 0) -
            (newHospital.distanceFromPatient ?? 0)) /
        1000;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔄 Closer hospital accepted! Switching to ${newHospital.name}'
          '${savedKm > 0.1 ? ' (saves ${savedKm.toStringAsFixed(1)} km)' : ''}',
        ),
        backgroundColor: const Color(0xFF1565C0),
        duration: const Duration(seconds: 4),
      ),
    );

    NavigationService.navigateTo(
      newHospital.location,
      origin: _searchLocation,
      label: newHospital.name,
    );
    _startHospitalArrivalWatch(newHospital);
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

                    // ── Auto-sending initial requests banner ──
                    if (_autoSendingInitial)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFF3E5F5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7B1FA2)),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📡 Automatically contacting top 2 hospitals…',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7B1FA2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Auto re-route banner ──
                    if (_activeHospitalId != null &&
                        _autoRequestedIds.any(
                            (id) => _requestStatus[id] == 'pending'))
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFE3F2FD),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1565C0)),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '🔍 Checking better-ranked hospitals in background…',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                                                      vitals: widget.vitals,
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
                                        // ── Route-changed chip (accepted but no longer active) ──
                                        if (status == 'accepted' &&
                                            h.id != _activeHospitalId &&
                                            _activeHospitalId != null)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 6, 4),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade400),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.swap_horiz,
                                                      size: 14,
                                                      color: Colors
                                                          .grey.shade600),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Route changed to closer hospital',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // ── Live distance badge (when geo-fence active) ──
                                        if (h.id == _activeHospitalId &&
                                            _monitoredHospitalId == h.id &&
                                            _distanceToHospitalM.isFinite)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 6, 4),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _distanceToHospitalM <
                                                        150
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFE3F2FD),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _distanceToHospitalM <
                                                          150
                                                      ? const Color(0xFF388E3C)
                                                      : const Color(0xFF1976D2),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _distanceToHospitalM < 150
                                                        ? Icons.check_circle
                                                        : Icons.my_location,
                                                    size: 16,
                                                    color: _distanceToHospitalM <
                                                            150
                                                        ? const Color(
                                                            0xFF388E3C)
                                                        : const Color(
                                                            0xFF1976D2),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _distanceToHospitalM < 1000
                                                        ? '${_distanceToHospitalM.round()} m to hospital'
                                                        : '${(_distanceToHospitalM / 1000).toStringAsFixed(1)} km to hospital',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _distanceToHospitalM <
                                                              150
                                                          ? const Color(
                                                              0xFF388E3C)
                                                          : const Color(
                                                              0xFF1976D2),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // ── Navigate button (only for active hospital) ──
                                        if (h.id == _activeHospitalId)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 6, 6),
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                  Icons.navigation,
                                                  size: 16,
                                                  color: Colors.white),
                                              label: const Text(
                                                'Navigate to Hospital 🗺',
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
                                                origin: _searchLocation,
                                                label: h.name,
                                              ),
                                            ),
                                          ),
                                        // ── Arrived at Hospital → End Case (only for active) ──
                                        if (h.id == _activeHospitalId)
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
                                                    _autoRequestedIds.contains(h.id)
                                                        ? 'Checking closer option…'
                                                        : 'Waiting for hospital response…',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: _autoRequestedIds.contains(h.id)
                                                            ? const Color(0xFF1565C0)
                                                            : Colors.grey.shade600),
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
