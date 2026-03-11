import 'package:google_maps_flutter/google_maps_flutter.dart';

class CaseModel {
  final String caseId;
  final String patientName;
  final String emergencyType;
  final LatLng patientLocation;
  final String dispatchedBy; // e.g. "108 Control"

  CaseModel({
    required this.caseId,
    required this.patientName,
    required this.emergencyType,
    required this.patientLocation,
    required this.dispatchedBy,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      caseId: json['caseId'] ?? '',
      patientName: json['patientName'] ?? '',
      emergencyType: json['emergencyType'] ?? '',
      patientLocation: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      dispatchedBy: json['dispatchedBy'] ?? '108 Control',
    );
  }
}
