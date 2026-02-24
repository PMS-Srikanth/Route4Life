import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../models/driver_model.dart';

/// Firebase Authentication service.
/// After login via Firebase, we also call our backend to get the driver profile.
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in with phone credential from Firebase OTP flow.
  static Future<DriverModel?> signInWithCredential(
      PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) return null;

      final token = await firebaseUser.getIdToken() ?? '';

      // Try to fetch driver profile from backend (skip if URL is placeholder)
      if (!AppConstants.baseUrl.contains('YOUR_BACKEND_URL')) {
        try {
          final response = await http.get(
            Uri.parse('${AppConstants.baseUrl}/auth/driver/${firebaseUser.uid}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return DriverModel.fromJson({...data, 'token': token});
          }
        } catch (_) {
          // Backend unreachable — fall through to basic model
        }
      }

      // Return basic driver model from Firebase user (works without backend)
      return DriverModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Driver',
        vehicleNumber: 'AP39AB1234',
        phone: firebaseUser.phoneNumber ?? '',
        token: token,
      );
    } catch (e) {
      return null;
    }
  }

  /// Send OTP to phone number. Callbacks handle the result.
  static Future<void> sendOTP({
    required String phoneNumber, // e.g. "+919999999999"
    required Function(PhoneAuthCredential) onAutoVerified,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify OTP entered by user.
  static Future<DriverModel?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
