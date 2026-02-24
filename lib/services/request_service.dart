import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/hospital_model.dart';
import '../models/request_model.dart';
import '../models/vitals_model.dart';

class RequestService {
  /// Send a bed/admission request to a list of ranked hospitals.
  /// Returns list of request results (each with hospitalId + status).
  static Future<List<RequestModel>> sendRequests({
    required List<HospitalModel> hospitals,
    required String caseId,
    required String emergencyType,
  }) async {
    final results = <RequestModel>[];

    for (final hospital in hospitals) {
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.baseUrl}${AppConstants.requestEndpoint}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'hospitalId': hospital.id,
            'caseId': caseId,
            'emergencyType': emergencyType,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          results.add(RequestModel.fromJson(data));
        }
      } catch (_) {
        // Skip failed requests silently
      }
    }

    return results;
  }

  /// Send a single doctor availability request from the Nearby Hospitals screen.
  /// Returns the request ID string on success, or 'ERR:...' on failure.
  static Future<String?> sendRequest({
    required String hospitalId,
    String emergencyType = 'Critical',
    String? vehicleNumber,
    double? distanceKm,
    VitalsModel? vitals,
  }) async {
    try {
      final caseId = 'manual-${DateTime.now().millisecondsSinceEpoch}';
      final uri = Uri.parse('${AppConstants.baseUrl}/request');

      // ── Multipart (when audio file present) ──────────────────────────────
      if (vitals != null && vitals.hasAudio) {
        final request = http.MultipartRequest('POST', uri)
          ..fields['hospitalId'] = hospitalId
          ..fields['caseId'] = caseId
          ..fields['emergencyType'] = emergencyType
          ..fields['vitals'] = jsonEncode(vitals.toJson());
        if (vehicleNumber != null) request.fields['vehicleNumber'] = vehicleNumber;
        if (distanceKm != null) request.fields['distanceKm'] = distanceKm.toString();

        final audioFile = File(vitals.audioFilePath!);
        if (await audioFile.exists()) {
          request.files.add(await http.MultipartFile.fromPath(
            'audio',
            vitals.audioFilePath!,
            filename: 'voice_note.m4a',
          ));
        }

        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final body = await streamed.stream.bytesToString();
        if (streamed.statusCode == 200 || streamed.statusCode == 201) {
          return jsonDecode(body)['_id'] as String?;
        }
        return 'ERR:${streamed.statusCode}';
      }

      // ── Plain JSON (no audio) ────────────────────────────────────────────
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hospitalId': hospitalId,
              'caseId': caseId,
              'emergencyType': emergencyType,
              if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
              if (distanceKm != null) 'distanceKm': distanceKm,
              if (vitals != null && vitals.hasVitals)
                'vitals': vitals.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['_id'] as String?;
      }
      return 'ERR:${response.statusCode}';
    } on Exception catch (e) {
      return 'ERR:$e';
    }
  }

  /// Poll a specific request to check if accepted.
  static Future<RequestStatus> checkRequestStatus(String requestId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}${AppConstants.requestEndpoint}/$requestId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data).status;
      }
      return RequestStatus.pending;
    } catch (_) {
      return RequestStatus.pending;
    }
  }
}
