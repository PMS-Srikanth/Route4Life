import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hospital_model.dart';
import '../services/hospital_service.dart';
import '../services/ranking_service.dart';

class HospitalController extends ChangeNotifier {
  List<HospitalModel> hospitals = [];
  List<HospitalModel> rankedHospitals = [];
  HospitalModel? selectedHospital;
  bool isLoading = false;
  String? error;

  Future<void> loadAndRank(LatLng patientLocation) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      hospitals = await HospitalService.fetchHospitals(near: patientLocation);
      rankedHospitals = RankingService.rankHospitals(
        hospitals: hospitals,
        fromLocation: patientLocation,
      );

      if (rankedHospitals.isNotEmpty) {
        selectedHospital = rankedHospitals.first;
      }
    } catch (e) {
      error = 'Failed to load hospitals';
    }

    isLoading = false;
    notifyListeners();
  }

  void selectHospital(HospitalModel hospital) {
    selectedHospital = hospital;
    notifyListeners();
  }
}
