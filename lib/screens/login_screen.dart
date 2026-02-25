import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  String? _error;

  // ── Step 1: Send OTP ────────────────────────────────────────────────────
  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final e164 = phone.startsWith('+') ? phone : '+91$phone';

    await FirebaseAuthService.sendOTP(
      phoneNumber: e164,
      onAutoVerified: (credential) async {
        // Auto-verified via Android SMS Retriever
        await _signInWithCredential(credential);
      },
      onCodeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 OTP sent! Check your SMS.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      },
      onFailed: (e) {
        if (!mounted) return;
        String msg;
        switch (e.code) {
          case 'invalid-phone-number':
            msg = 'Invalid phone number. Enter a 10-digit Indian mobile number.';
            break;
          case 'too-many-requests':
            msg = 'Too many OTP requests. Please wait a few minutes and try again.';
            break;
          case 'quota-exceeded':
            msg = 'SMS quota exceeded for today. Try again later.';
            break;
          case 'network-request-failed':
            msg = 'No internet connection. Check your network and retry.';
            break;
          case 'app-not-authorized':
            msg = 'App not authorised for Firebase. Check SHA-1 in Firebase Console.';
            break;
          case 'internal-error':
            msg = 'Firebase internal error — check that SHA-1 fingerprint is added '
                'in Firebase Console → Project Settings → Android App, '
                'and that Phone Auth is enabled.';
            break;
          case 'missing-client-identifier':
            msg = 'reCAPTCHA / SafetyNet check failed. Add your SHA-1 to Firebase Console.';
            break;
          default:
            final raw = e.message ?? '';
            if (raw.toLowerCase().contains('internal')) {
              msg = 'Firebase setup issue: add SHA-1 fingerprint in Firebase Console '
                  '(Project Settings → Your Android App). Code: ${e.code}';
            } else {
              msg = raw.isNotEmpty ? raw : 'Failed to send OTP (${e.code})';
            }
        }
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      },
    );
  }

  // ── Step 2: Verify OTP ───────────────────────────────────────────────────
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    if (_verificationId == null) return;

    setState(() { _isLoading = true; _error = null; });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final driver = await FirebaseAuthService.signInWithCredential(credential);
    if (!mounted) return;

    if (driver != null) {
      AuthService.setCurrentDriver(driver);
      ApiService.setToken(driver.token);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      setState(() {
        _error = 'Login failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE53935),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.local_hospital, size: 64, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'Route4Life',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const Text(
                  'Ambulance Driver App',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),
                _buildCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otpSent ? 'Enter OTP' : 'Login with Phone',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (!_otpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'OTP sent to +91 ${_phoneController.text.trim()}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Check your SMS inbox for a 6-digit code.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  prefixIcon: Icon(Icons.sms),
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: 'Enter OTP from SMS',
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _otpSent = false;
                          _otpController.clear();
                          _error = null;
                        }),
                child: const Text('Change number'),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_otpSent ? _verifyOTP : _sendOTP),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _otpSent ? 'Verify OTP' : 'Send OTP',
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
