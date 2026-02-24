import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/hospital_model.dart';
import '../models/request_model.dart';

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
  /// Returns the request ID string on success, null on failure.
  static Future<String?> sendRequest({
    required String hospitalId,
    String emergencyType = 'Critical',
    String? vehicleNumber,
    double? distanceKm,
  }) async {
    try {
      final caseId = 'manual-${DateTime.now().millisecondsSinceEpoch}';
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hospitalId': hospitalId,
              'caseId': caseId,
              'emergencyType': emergencyType,
              if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
              if (distanceKm != null) 'distanceKm': distanceKm,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['_id'] as String?;
      }
      // Return status code as part of error so UI can show it
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
