import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/app_state.dart';
import '../core/thresholds.dart';
import '../models/case_model.dart';
import '../models/hospital_model.dart';
import '../services/location_service.dart';
import '../services/hospital_service.dart';
import '../services/ranking_service.dart';
import '../services/request_service.dart';

class CaseController extends ChangeNotifier {
  AppState appState = AppState.idle;
  CaseModel? activeCase;
  LatLng? driverLocation;
  HospitalModel? assignedHospital;
  bool hospitalLocked = false;

  List<HospitalModel> rankedHospitals = [];

  StreamSubscription? _locationSub;

  void setCase(CaseModel caseModel) {
    activeCase = caseModel;
    appState = AppState.navigatingToPatient;
    _safeNotify();
    _startLocationTracking();
    _fetchAndRankHospitals();
  }

  void _startLocationTracking() {
    _locationSub?.cancel();
    _locationSub =
        LocationService.getLiveLocationStream().listen((position) {
      driverLocation = LatLng(position.latitude, position.longitude);
      _safeNotify();

      if (activeCase != null && !hospitalLocked) {
        final distance = LocationService.distanceBetween(
          driverLocation!,
          activeCase!.patientLocation,
        );

        if (distance <= AppThresholds.nearPatientRadius &&
            appState == AppState.navigatingToPatient) {
          appState = AppState.nearPatient;
          _safeNotify();
          _fetchAndRankHospitals(); // re-rank near patient
        }
      }
    });
  }

  Future<void> _fetchAndRankHospitals() async {
    if (activeCase == null) return;

    final hospitals = await HospitalService.fetchHospitals(
      near: activeCase!.patientLocation,
    );

    rankedHospitals = RankingService.rankHospitals(
      hospitals: hospitals,
      fromLocation: activeCase!.patientLocation,
    );

    if (rankedHospitals.isNotEmpty) {
      assignedHospital = rankedHospitals.first;
    }

    _safeNotify();

    if (activeCase != null) {
      await RequestService.sendRequests(
        hospitals: rankedHospitals,
        caseId: activeCase!.caseId,
        emergencyType: activeCase!.emergencyType,
      );
    }
  }

  void confirmPickup() {
    hospitalLocked = true;
    appState = AppState.patientOnBoard;
    _safeNotify();
  }

  void completeCase() {
    appState = AppState.caseComplete;
    _safeNotify();
  }

  /// Notify only if controller hasn't been disposed yet.
  void _safeNotify() {
    try {
      notifyListeners();
    } catch (_) {
      // Already disposed — ignore
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}
