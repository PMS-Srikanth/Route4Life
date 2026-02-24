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
        // Auto-verified (Android SMS retriever)
        await _signInWithCredential(credential);
      },
      onCodeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.message ?? 'Failed to send OTP';
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
              Text(
                'OTP sent to +91 ${_phoneController.text.trim()}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  prefixIcon: Icon(Icons.sms),
                  border: OutlineInputBorder(),
                  counterText: '',
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
