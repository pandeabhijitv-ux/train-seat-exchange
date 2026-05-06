import 'package:flutter/material.dart';
import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

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
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  static const Map<String, String> _planToProductId = {
    'monthly': 'monthly_125',
    'quarterly': 'quarterly_275',
    'yearly': 'yearly_950',
  };

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  UserProfile? _profile;
  List<dynamic> _plans = [];
  Map<String, ProductDetails> _productsById = {};
  Map<String, dynamic>? _subscription;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _storeAvailable = false;
  String? _storeError;

  String? _pendingPlanCode;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) {
        if (!mounted) {
          return;
        }
        _showSnackBar('Purchase stream error: $error', Colors.red);
      },
    );
    _loadData();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _profileService.getProfile();
      final plans = await _apiService.getSubscriptionPlans();

        final available = await _inAppPurchase.isAvailable();
        final productIds = plans
          .map((raw) => _resolveProductId(raw as Map<String, dynamic>))
          .whereType<String>()
          .toSet();
      Map<String, ProductDetails> productsById = {};
      String? storeError;

      if (available) {
        final response = await _inAppPurchase.queryProductDetails(productIds);
        productsById = {
          for (final product in response.productDetails) product.id: product,
        };
        if (response.error != null) {
          storeError = response.error!.message;
        } else if (response.notFoundIDs.isNotEmpty) {
          storeError =
              'Some products are not found in Play Console: ${response.notFoundIDs.join(', ')}';
        }
      } else {
        storeError = 'Google Play Billing is not available on this device.';
      }

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
        _productsById = productsById;
        _subscription = subscription;
        _storeAvailable = available;
        _storeError = storeError;
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

  String? _resolveProductId(Map<String, dynamic> plan) {
    final backendProductId = plan['play_product_id']?.toString();
    if (backendProductId != null && backendProductId.isNotEmpty) {
      return backendProductId;
    }

    final planCode = plan['code']?.toString();
    return _planToProductId[planCode];
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

    if (!_storeAvailable) {
      _showSnackBar('Google Play Billing is unavailable on this device.', Colors.orange);
      return;
    }

    final planCode = plan['code']?.toString();
    final productId = _resolveProductId(plan);
    if (planCode == null || productId == null) {
      _showSnackBar('Unsupported subscription plan.', Colors.red);
      return;
    }

    final productDetails = _productsById[productId];
    if (productDetails == null) {
      _showSnackBar(
        'Product not available in Play Console yet: $productId',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _pendingPlanCode = planCode;
    });

    try {
      final purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: profile.phone,
      );

      final launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!launched) {
        throw StateError('Unable to launch Google Play purchase flow.');
      }
    } catch (error) {
      _showSnackBar(error.toString(), Colors.red);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() {
            _isProcessing = true;
          });
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _showSnackBar(
          'Purchase failed: ${purchase.error?.message ?? 'Unknown error'}',
          Colors.red,
        );
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        _showSnackBar('Purchase cancelled.', Colors.orange);
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      } else if (
          purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchaseWithBackend(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    final profile = _profile;
    if (profile == null) {
      _showSnackBar('Verify phone profile before subscription purchase.', Colors.orange);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData;
    if (purchaseToken.isEmpty) {
      _showSnackBar('Missing purchase token from Google Play.', Colors.red);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    try {
      await _apiService.verifyPlaySubscriptionPurchase(
        phone: profile.phone,
        productId: purchase.productID,
        purchaseToken: purchaseToken,
        purchaseId: purchase.purchaseID,
      );
      await _loadData();
      _showSnackBar('Subscription activated successfully.', Colors.green);
    } catch (error) {
      _showSnackBar('Purchase verification failed: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
    final priceInr = plan['price_inr']?.toString() ?? '';
    final desc = plan['description']?.toString() ?? '';
    final planCode = plan['code']?.toString() ?? '';
    final productId = _resolveProductId(plan);
    final productDetails = productId == null ? null : _productsById[productId];
    final displayPrice = productDetails?.price ?? '₹$priceInr';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name - $displayPrice',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(desc),
            const SizedBox(height: 4),
            Text(
              'Product ID: ${productId ?? 'N/A'}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || productDetails == null
                    ? null
                    : () => _openCheckout(plan),
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
                          const SizedBox(height: 4),
                          Text(
                            _storeAvailable
                                ? 'Google Play Billing connected'
                                : 'Google Play Billing unavailable',
                            style: TextStyle(
                              color: _storeAvailable ? Colors.green.shade800 : Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                          if (_pendingPlanCode != null) ...[
                            const SizedBox(height: 6),
                            Text('Latest selected plan: $_pendingPlanCode'),
                          ],
                          if (_storeError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _storeError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _inAppPurchase.restorePurchases(),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore Purchases'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._plans.map((raw) => _buildPlanCard(raw as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }
}
