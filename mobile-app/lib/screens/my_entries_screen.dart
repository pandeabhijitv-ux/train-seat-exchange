import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import 'otp_screen.dart';
import 'subscription_screen.dart';

class MyEntriesScreen extends StatefulWidget {
  const MyEntriesScreen({super.key});

  @override
  State<MyEntriesScreen> createState() => _MyEntriesScreenState();
}

class _MyEntriesScreenState extends State<MyEntriesScreen> {
  static const Duration _autoRefreshInterval = Duration(seconds: 25);

  final ApiService _apiService = ApiService();
  final UserProfileService _profileService = UserProfileService();

  UserProfile? _profile;
  List<dynamic> _entries = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  DateTime? _lastRefreshedAt;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _loadEntries(showLoader: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _loadEntries(showLoader: false);
    });
  }

  Map<int, int> _extractMatchMap(List<dynamic> entries) {
    final result = <int, int>{};
    for (final raw in entries) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = raw['id'];
      if (id is! int) {
        continue;
      }
      result[id] = raw['match_count'] as int? ?? 0;
    }
    return result;
  }

  int _countNewMatches(Map<int, int> previous, Map<int, int> next) {
    var delta = 0;
    for (final entry in next.entries) {
      final oldCount = previous[entry.key] ?? 0;
      if (entry.value > oldCount) {
        delta += entry.value - oldCount;
      }
    }
    return delta;
  }

  Future<void> _loadEntries({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final profile = await _profileService.getProfile();
      if (!mounted) {
        return;
      }

      if (profile == null) {
        setState(() {
          _profile = null;
          _entries = [];
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.getMyActiveEntries(profile.phone);
      if (!mounted) {
        return;
      }

      final nextEntries = (response['entries'] as List<dynamic>? ?? []);
      final previousMatchMap = _extractMatchMap(_entries);
      final nextMatchMap = _extractMatchMap(nextEntries);
      final newMatches = _hasLoadedOnce
          ? _countNewMatches(previousMatchMap, nextMatchMap)
          : 0;

      setState(() {
        _profile = profile;
        _entries = nextEntries;
        _isLoading = false;
        _hasLoadedOnce = true;
        _lastRefreshedAt = DateTime.now();
      });

      if (newMatches > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have $newMatches new potential match(es).'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error.toString().contains('active subscription is required')) {
        setState(() {
          _isLoading = false;
        });
        _showSubscriptionPrompt();
        return;
      }

      if (showLoader) {
        setState(() {
          _isLoading = false;
        });
      }
      if (showLoader) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load entries: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSubscriptionPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Required'),
        content: const Text(
          'My Active Entries is available for active subscribers. Choose Per Transaction (₹15), Monthly (₹125), Quarterly (₹275), or Yearly (₹950).',
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

  String _formatLastRefreshed() {
    final value = _lastRefreshedAt;
    if (value == null) {
      return 'Not refreshed yet';
    }
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _buildUnauthenticatedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Verify your phone to see active entries',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OTPScreen(),
                  ),
                );
                if (result == true) {
                  _loadEntries(showLoader: true);
                }
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Verify Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final int matchCount = entry['match_count'] as int? ?? 0;
    final List<dynamic> preview = entry['match_preview'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Train ${entry['train_number']} • ${entry['train_date']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: matchCount > 0 ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    matchCount > 0 ? '$matchCount match(es)' : 'No match yet',
                    style: TextStyle(
                      color: matchCount > 0 ? Colors.green.shade800 : Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('You have: ${entry['current_bogie']}-${entry['current_seat']}'),
            Text('You want: ${entry['desired_bogie']}-${entry['desired_seat']}'),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text(
                'Top match preview',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...preview.take(2).map((raw) {
                final match = raw as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${match['current_bogie']}-${match['current_seat']} '
                    'wants ${match['desired_bogie']}-${match['desired_seat']} '
                    '• ${match['phone']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Active Entries'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadEntries(showLoader: false),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? _buildUnauthenticatedState()
                : _entries.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'No active entries found.',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Showing ${_entries.length} active entries for ${_profile!.phone}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Auto-refresh every ${_autoRefreshInterval.inSeconds}s',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Last refreshed: ${_formatLastRefreshed()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._entries.map((entry) => _buildEntryCard(entry as Map<String, dynamic>)),
                        ],
                      ),
      ),
    );
  }
}
