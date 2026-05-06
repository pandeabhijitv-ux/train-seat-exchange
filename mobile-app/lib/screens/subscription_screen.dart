import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import 'otp_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final ApiService _apiService = ApiService();
  final UserProfileService _profileService = UserProfileService();
  late final Razorpay _razorpay;

  UserProfile? _profile;
  List<dynamic> _plans = [];
  Map<String, dynamic>? _subscription;
  bool _isLoading = true;
  bool _isProcessing = false;

  String? _pendingPhone;
  String? _pendingOrderId;
  String? _pendingPlanCode;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _profileService.getProfile();
      final plans = await _apiService.getSubscriptionPlans();

      Map<String, dynamic>? subscription;
      if (profile != null) {
        final status = await _apiService.getSubscriptionStatus(profile.phone);
        subscription = status['subscription'] as Map<String, dynamic>?;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _plans = plans;
        _subscription = subscription;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      _showSnackBar(error.toString(), Colors.red);
    }
  }

  bool get _hasActiveSubscription {
    final active = _subscription?['is_active'];
    if (active is bool) {
      return active;
    }
    return false;
  }

  String _formatExpiry() {
    final expiresAt = _subscription?['expires_at']?.toString();
    if (expiresAt == null || expiresAt.isEmpty) {
      return 'No active subscription';
    }
    return expiresAt;
  }

  Future<void> _openCheckout(Map<String, dynamic> plan) async {
    final profile = _profile;
    if (profile == null) {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const OTPScreen()),
      );
      if (verified == true) {
        await _loadData();
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final orderResult = await _apiService.createSubscriptionOrder(
        phone: profile.phone,
        planCode: plan['code'].toString(),
      );

      final order = orderResult['order'] as Map<String, dynamic>;
      final keyId = order['key_id']?.toString();
      if (keyId == null || keyId.isEmpty) {
        throw StateError('Payment key is missing. Razorpay may not be configured yet.');
      }

      _pendingPhone = profile.phone;
      _pendingOrderId = order['order_id']?.toString();
      _pendingPlanCode = plan['code']?.toString();

      final options = {
        'key': keyId,
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'name': 'RailSeatExchange',
        'description': '${plan['name']} Subscription',
        'order_id': order['order_id'],
        'prefill': {
          'contact': profile.phone,
          'name': profile.name,
        },
        'theme': {
          'color': '#E65100',
        },
      };

      _razorpay.open(options);
    } catch (error) {
      _showSnackBar(error.toString(), Colors.red);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final phone = _pendingPhone;
    final orderId = response.orderId ?? _pendingOrderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (phone == null || orderId == null || paymentId == null || signature == null) {
      _showSnackBar('Payment succeeded but verification data is incomplete.', Colors.orange);
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    try {
      await _apiService.verifySubscriptionPayment(
        phone: phone,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

      await _loadData();
      _showSnackBar('Subscription activated successfully.', Colors.green);
    } catch (error) {
      _showSnackBar('Payment verification failed: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isProcessing = false;
    });
    _showSnackBar('Payment cancelled or failed (${response.code}).', Colors.orange);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar('External wallet selected: ${response.walletName}', Colors.blue);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name']?.toString() ?? '';
    final price = plan['price_inr']?.toString() ?? '';
    final desc = plan['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name - ₹$price',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(desc),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _openCheckout(plan),
                child: const Text('Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: _hasActiveSubscription ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasActiveSubscription ? 'Active Subscription' : 'No Active Subscription',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text('Valid until: ${_formatExpiry()}'),
                          if (_pendingPlanCode != null) ...[
                            const SizedBox(height: 6),
                            Text('Latest selected plan: $_pendingPlanCode'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a plan to unlock create, search and active entries features:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._plans.map((raw) => _buildPlanCard(raw as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }
}
