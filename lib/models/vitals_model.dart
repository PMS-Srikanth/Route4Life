/// Holds patient vitals + voice note data collected in the ambulance.
class VitalsModel {
  final int? heartRate;
  final String? bloodPressure;
  final int? spo2;
  final String consciousness;
  final String conditionNotes;
  final String? audioFilePath; // local file path on device

  const VitalsModel({
    this.heartRate,
    this.bloodPressure,
    this.spo2,
    this.consciousness = 'Alert',
    this.conditionNotes = '',
    this.audioFilePath,
  });

  bool get hasAudio => audioFilePath != null && audioFilePath!.isNotEmpty;

  bool get hasVitals =>
      heartRate != null || bloodPressure != null || spo2 != null ||
      conditionNotes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'heartRate': heartRate,
        'bloodPressure': bloodPressure,
        'spo2': spo2,
        'consciousness': consciousness,
        'conditionNotes': conditionNotes,
      };
}
