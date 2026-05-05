import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/firebase_bootstrap_service.dart';
import '../services/user_profile_service.dart';
import 'create_entry_screen.dart';

class OTPScreen extends StatefulWidget {
  final bool navigateToCreateEntry;

  const OTPScreen({
    super.key,
    this.navigateToCreateEntry = false,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _apiService = ApiService();
  final _userProfileService = UserProfileService();
  
  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_nameController.text.trim().length < 2) {
      setState(() {
        _errorMessage = 'Please enter your full name';
      });
      return;
    }

    if (_phoneController.text.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseBootstrapService.ensureInitialized();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneController.text}',
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _completeRegistration(credential, successMessage: 'Phone verified automatically');
        },
        verificationFailed: (exception) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _errorMessage = exception.message ?? 'Failed to send OTP';
          });
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpSent = true;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_nameController.text.trim().length < 2) {
      setState(() {
        _errorMessage = 'Please enter your full name';
      });
      return;
    }

    if (_otpController.text.length < 4) {
      setState(() {
        _errorMessage = 'Please enter valid OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verificationId = _verificationId;
      if (verificationId == null || verificationId.isEmpty) {
        throw StateError('OTP session expired. Please request a new OTP.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _otpController.text.trim(),
      );

      await _completeRegistration(credential);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeRegistration(
    PhoneAuthCredential credential, {
    String successMessage = 'Registration complete',
  }) async {
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw StateError('Phone verification failed. Please try again.');
    }

    await firebaseUser.getIdToken(true);
    final registration = await _apiService.registerUser(
      phone: _phoneController.text,
      name: _nameController.text.trim(),
    );
    final userJson = registration['user'] as Map<String, dynamic>;
    await _userProfileService.saveProfile(UserProfile.fromJson(userJson));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(registration['message'] ?? successMessage),
        backgroundColor: Colors.green,
      ),
    );

    if (widget.navigateToCreateEntry) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CreateEntryScreen(phone: _phoneController.text),
        ),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register & Verify'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create your verified profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'ll verify your phone using Firebase and use it as your contact number for seat exchange.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !_otpSent,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              enabled: !_otpSent,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'By continuing, you agree that your registered phone number can be shown to other verified passengers when a seat exchange match is found.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_otpSent)
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send OTP'),
              ),
            
            if (_otpSent) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify OTP'),
              ),
              TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: const Text('Resend OTP'),
              ),
            ],
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
