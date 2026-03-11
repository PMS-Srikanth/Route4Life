import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/driver_model.dart';

/// Password-based auth service (backend / mock fallback).
///
/// For OTP-based phone auth, see [FirebaseAuthService].
/// Switch the login screen to use FirebaseAuthService when
/// google-services.json has been placed in android/app/.
class AuthService {
  static DriverModel? currentDriver;

  // ── Mock credentials for testing without a backend ──────────────────────
  static const _mockPhone = '9999999999';
  static const _mockPassword = 'password123';
  static final _mockDriver = DriverModel(
    id: 'mock_001',
    name: 'Ravi Kumar',
    vehicleNumber: 'AP39AB1234',  // Vijayawada registration
    phone: _mockPhone,
    token: 'mock_token',
  );
  // ────────────────────────────────────────────────────────────────────────

  static Future<DriverModel?> login(String phone, String password) async {
    // Use mock login if backend URL is still a placeholder
    if (AppConstants.baseUrl.contains('YOUR_BACKEND_URL')) {
      if (phone == _mockPhone && password == _mockPassword) {
        currentDriver = _mockDriver;
        return currentDriver;
      }
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentDriver = DriverModel.fromJson(data);
        return currentDriver;
      }
      // Backend responded with error — fallback to mock during dev
      if (phone == _mockPhone && password == _mockPassword) {
        currentDriver = _mockDriver;
        return currentDriver;
      }
      return null;
    } catch (_) {
      // Backend unreachable — try mock
      if (phone == _mockPhone && password == _mockPassword) {
        currentDriver = _mockDriver;
        return currentDriver;
      }
      return null;
    }
  }

  /// Called after Firebase OTP login succeeds to store the driver profile.
  static void setCurrentDriver(DriverModel driver) {
    currentDriver = driver;
  }

  static void logout() {
    currentDriver = null;
  }

  static bool get isLoggedIn => currentDriver != null;
}
