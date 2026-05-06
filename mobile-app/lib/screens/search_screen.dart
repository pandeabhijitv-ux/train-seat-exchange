import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import 'otp_screen.dart';
import 'subscription_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pnrController = TextEditingController();
  final _trainNumberController = TextEditingController();
  final _trainDateController = TextEditingController();
  final _currentBogieController = TextEditingController();
  final _currentSeatController = TextEditingController();
  final _desiredBogieController = TextEditingController();
  final _desiredSeatController = TextEditingController();

  final ApiService _apiService = ApiService();
  final UserProfileService _userProfileService = UserProfileService();

  List<dynamic> _searchResults = [];
  UserProfile? _profile;
  bool _isLoading = false;
  bool _isFetchingPnr = false;
  bool _hasSearched = false;
  bool _pnrVerified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _pnrController.dispose();
    _trainNumberController.dispose();
    _trainDateController.dispose();
    _currentBogieController.dispose();
    _currentSeatController.dispose();
    _desiredBogieController.dispose();
    _desiredSeatController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _userProfileService.getProfile();
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
    });
  }

  Future<void> _verifyPnr() async {
    if (_pnrController.text.trim().length != 10) {
      _showSnackBar('PNR must be 10 digits', Colors.red);
      return;
    }

    setState(() {
      _isFetchingPnr = true;
    });

    try {
      final result = await _apiService.verifyPNR(_pnrController.text.trim());
      if (!mounted) {
        return;
      }

      setState(() {
        _trainNumberController.text = result['train_number'] ?? '';
        _trainDateController.text = result['date_of_journey'] ?? '';
        _currentBogieController.text = result['bogie'] ?? '';
        _currentSeatController.text = result['seat_number'] ?? '';
        _pnrVerified = true;
        _isFetchingPnr = false;
      });

      _showSnackBar('PNR verified. Current seat details loaded.', Colors.green);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFetchingPnr = false;
        _pnrVerified = false;
      });
      _showSnackBar(error.toString(), Colors.red);
    }
  }

  Future<void> _searchEntries() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_pnrVerified) {
      _showSnackBar(
        'Verify your PNR first so the app can search nearby seats correctly.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final desiredBogie = _desiredBogieController.text.trim().toUpperCase();
      final results = await _apiService.searchEntries(
        trainNumber: _trainNumberController.text.trim(),
        trainDate: _trainDateController.text.trim(),
        bogie: desiredBogie.isEmpty ? null : desiredBogie,
        requesterPhone: _profile?.phone,
        currentBogie: _currentBogieController.text.trim().toUpperCase(),
        currentSeat: _currentSeatController.text.trim().toUpperCase(),
        desiredBogie: desiredBogie,
        desiredSeat: _desiredSeatController.text.trim().toUpperCase(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (error.toString().contains('active subscription is required')) {
        _showSubscriptionPrompt();
        return;
      }
      _showSnackBar('Search failed: ${error.toString()}', Colors.red);
    }
  }

  void _showSubscriptionPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Required'),
        content: const Text(
          'Search is available for active subscribers. Choose Per Transaction (₹15), Monthly (₹125), Quarterly (₹275), or Yearly (₹950).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _openVerificationFlow() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const OTPScreen(),
      ),
    );

    if (result == true) {
      await _loadProfile();
      if (mounted) {
        _showSnackBar(
          'Verification complete. Contact numbers are now visible.',
          Colors.green,
        );
      }
    }
  }

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) {
      return;
    }
    _showSnackBar('Phone number copied.', Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search By PNR'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildRegistrationBanner(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pnrController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: 'PNR Number',
                            hintText: 'Enter 10-digit PNR',
                            prefixIcon: Icon(Icons.confirmation_number_outlined),
                            border: OutlineInputBorder(),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length != 10) {
                              return 'Enter 10-digit PNR';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isFetchingPnr ? null : _verifyPnr,
                          child: _isFetchingPnr
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Fetch'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _trainNumberController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Train Number',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _trainDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Journey Date',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _currentBogieController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Your Current Bogie',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _currentSeatController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Your Current Seat',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Where do you want to move?',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _desiredBogieController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Desired Bogie',
                            hintText: 'A2 / B3',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _desiredSeatController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Desired Seat',
                            hintText: '12LB',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchEntries,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Find Probable Matches',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationBanner() {
    final isRegistered = _profile != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRegistered ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRegistered ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRegistered
                ? 'Verified as ${_profile!.name} (${_profile!.phone})'
                : 'Verify your phone to see full contact numbers.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isRegistered ? Colors.green.shade900 : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRegistered
                ? 'You can now view and copy other passengers\' full phone numbers.'
                : 'Unverified users can still search, but contact numbers stay masked until registration is completed.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
          if (!isRegistered) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openVerificationFlow,
                child: const Text('Verify Now'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Enter PNR and desired seat to find the nearest exchanges',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No seat exchanges found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No one has posted a matching request for this train yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        final proximityDetails = entry['proximity_details'];
        final hasProximity = proximityDetails != null;
        final contactVisible = entry['contact_visible'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: hasProximity ? 3 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Train ${entry['train_number']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry['train_date'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasProximity) ...[
                  const SizedBox(height: 8),
                  _buildProximityBadge(proximityDetails as Map),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HAS',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry['current_bogie']} - ${entry['current_seat']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.swap_horiz, color: Colors.blue),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'WANTS',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry['desired_bogie']} - ${entry['desired_seat']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                if (contactVisible)
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          entry['phone'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _copyPhone(entry['phone'] as String),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Number'),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact: ${entry['phone']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Register with OTP to see and copy the full contact number.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openVerificationFlow,
                            child: const Text('Verify to View Number'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProximityBadge(Map proximityDetails) {
    final matchQuality = proximityDetails['match_quality'] ?? 'fair';
    final seatDistance = proximityDetails['desired_seat_distance'] ?? 0;
    final bogieDistance = proximityDetails['desired_bogie_distance'] ?? 0;
    final isSameBogie = proximityDetails['is_same_bogie'] ?? false;

    Color badgeColor;
    Color textColor;
    String label;

    switch (matchQuality) {
      case 'excellent':
        badgeColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        label = 'Excellent Match';
        break;
      case 'good':
        badgeColor = Colors.lightGreen.shade100;
        textColor = Colors.lightGreen.shade900;
        label = 'Good Match';
        break;
      case 'fair':
        badgeColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        label = 'Fair Match';
        break;
      default:
        badgeColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        label = 'Poor Match';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        isSameBogie
            ? '$label • Same bogie • $seatDistance seats away'
            : '$label • $bogieDistance bogies away • $seatDistance seats away',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
