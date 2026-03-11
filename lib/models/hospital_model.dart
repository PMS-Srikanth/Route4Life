import 'package:google_maps_flutter/google_maps_flutter.dart';

class HospitalModel {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final bool icuAvailable;
  final bool doctorAvailable;
  final int icuBeds;
  final bool ventilatorAvailable;
  final bool oxygenAvailable;
  final bool bloodBankAvailable;
  final String phone;
  final String? assignedEmail;

  // Set at runtime after ranking
  double? distanceFromPatient; // in meters
  double? rankScore;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.icuAvailable,
    required this.doctorAvailable,
    required this.icuBeds,
    this.ventilatorAvailable = false,
    this.oxygenAvailable = true,
    this.bloodBankAvailable = false,
    required this.phone,
    this.assignedEmail,
    this.distanceFromPatient,
    this.rankScore,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      icuAvailable: json['icuAvailable'] ?? false,
      doctorAvailable: json['doctorAvailable'] ?? false,
      icuBeds: json['icuBeds'] ?? 0,
      ventilatorAvailable: json['ventilatorAvailable'] ?? false,
      oxygenAvailable: json['oxygenAvailable'] ?? true,
      bloodBankAvailable: json['bloodBankAvailable'] ?? false,
      phone: json['phone'] ?? '',
      assignedEmail: json['assignedEmail'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'address': address,
        'lat': location.latitude,
        'lng': location.longitude,
        'icuAvailable': icuAvailable,
        'doctorAvailable': doctorAvailable,
        'icuBeds': icuBeds,
        'ventilatorAvailable': ventilatorAvailable,
        'oxygenAvailable': oxygenAvailable,
        'bloodBankAvailable': bloodBankAvailable,
        'phone': phone,
        'assignedEmail': assignedEmail,
      };
}
