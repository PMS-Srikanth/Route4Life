import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/config.dart';

/// Generic API service for raw HTTP calls with auth token support.
class ApiService {
  static String? _authToken;

  static void setToken(String token) => _authToken = token;
  static void clearToken() => _authToken = null;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  static Future<Map<String, dynamic>?> get(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: _headers,
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
