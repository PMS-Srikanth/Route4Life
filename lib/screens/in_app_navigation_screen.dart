import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';

class InAppNavigationScreen extends StatefulWidget {
  final LatLng destination;
  final String destinationLabel;
  final LatLng? origin;
  /// Called when user taps "Arrived ✓". Pass null to just pop.
  final VoidCallback? onArrived;
  /// If true, "Arrived" ends the full case (pushes Dashboard).
  final bool endCaseOnArrival;

  const InAppNavigationScreen({
    super.key,
    required this.destination,
    required this.destinationLabel,
    this.origin,
    this.onArrived,
    this.endCaseOnArrival = false,
  });

  @override
  State<InAppNavigationScreen> createState() => _InAppNavigationScreenState();
}

class _InAppNavigationScreenState extends State<InAppNavigationScreen> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  LatLng? _currentPos;
  final Set<Marker> _markers = {};
  StreamSubscription<Position>? _posSub;
  double _distanceM = double.infinity;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    // Get initial position
    LatLng startPos = widget.origin ?? const LatLng(16.5062, 80.6480);
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      startPos = LatLng(p.latitude, p.longitude);
    } catch (_) {}

    setState(() => _currentPos = startPos);
    _distanceM = Geolocator.distanceBetween(
      startPos.latitude, startPos.longitude,
      widget.destination.latitude, widget.destination.longitude,
    );
    _updateMarkers(startPos);

    // Live position updates
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPos = newPos;
        _distanceM = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          widget.destination.latitude, widget.destination.longitude,
        );
      });
      _updateMarkers(newPos);
      // Animate camera to follow
      if (_mapCtrl.isCompleted) {
        final ctrl = await _mapCtrl.future;
        ctrl.animateCamera(CameraUpdate.newLatLng(newPos));
      }
    });
  }

  void _updateMarkers(LatLng from) {
    setState(() {
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId('current'),
          position: from,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Ambulance'),
        ))
        ..add(Marker(
          markerId: const MarkerId('dest'),
          position: widget.destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.destinationLabel),
        ));
    });
  }

  void _openInGoogleMaps() async {
    final dest = widget.destination;
    final origin = _currentPos;
    Uri uri;
    if (origin != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&travelmode=driving',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${dest.latitude},${dest.longitude}'
        '&travelmode=driving',
      );
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  void _onArrived() {
    if (widget.onArrived != null) {
      widget.onArrived!();
    } else if (widget.endCaseOnArrival) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distStr = _distanceM.isFinite ? _formatDist(_distanceM) : '—';

    return Scaffold(
      // ── App bar ──
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.destinationLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_distanceM.isFinite)
              Text(
                distStr + ' away',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Google Maps',
            onPressed: _openInGoogleMaps,
          ),
        ],
      ),

      body: Stack(
        children: [
          // ── Map ──
          _currentPos == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPos!,
                    zoom: 14,
                  ),
                  onMapCreated: (ctrl) => _mapCtrl.complete(ctrl),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                ),

          // ── Distance badge ──
          if (_distanceM.isFinite)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _distanceM < 150
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _distanceM < 150 ? Icons.check_circle : Icons.navigation,
                      color: Colors.white, size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _distanceM < 150
                          ? 'Almost there!'
                          : '$distStr to destination',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom arrived button ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Open in Google Maps button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.navigation, color: Color(0xFF1976D2)),
                        label: const Text(
                          'Open Navigation in Google Maps',
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1976D2), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openInGoogleMaps,
                      ),
                    ),
                  ),
                  // Arrived button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_hospital, color: Colors.white),
                      label: Text(
                        widget.endCaseOnArrival
                            ? 'Arrived at ${widget.destinationLabel} ✓ — End Case'
                            : 'Arrived at ${widget.destinationLabel} ✓',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _onArrived,
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
