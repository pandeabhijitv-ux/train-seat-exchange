import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/seat_entry.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trainNumberController = TextEditingController();
  final _trainDateController = TextEditingController();
  final _bogieController = TextEditingController();
  
  // Proximity search fields (optional)
  final _currentBogieController = TextEditingController();
  final _currentSeatController = TextEditingController();
  final _desiredBogieController = TextEditingController();
  final _desiredSeatController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _useProximitySearch = false;  // Toggle for smart search

  @override
  void dispose() {
    _trainNumberController.dispose();
    _trainDateController.dispose();
    _bogieController.dispose();
    _currentBogieController.dispose();
    _currentSeatController.dispose();
    _desiredBogieController.dispose();
    _desiredSeatController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    
    if (picked != null) {
      setState(() {
        _trainDateController.text = 
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _searchEntries() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _apiService.searchEntries(
        trainNumber: _trainNumberController.text.trim(),
        trainDate: _trainDateController.text.trim(),
        bogie: _bogieController.text.trim().isEmpty 
            ? null 
            : _bogieController.text.trim(),
        // Pass proximity parameters if smart search is enabled
        currentBogie: _useProximitySearch && _currentBogieController.text.isNotEmpty
            ? _currentBogieController.text.trim()
            : null,
        currentSeat: _useProximitySearch && _currentSeatController.text.isNotEmpty
            ? _currentSeatController.text.trim()
            : null,
        desiredBogie: _useProximitySearch && _desiredBogieController.text.isNotEmpty
            ? _desiredBogieController.text.trim()
            : null,
        desiredSeat: _useProximitySearch && _desiredSeatController.text.isNotEmpty
            ? _desiredSeatController.text.trim()
            : null,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Seat Exchanges'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Smart Search Toggle
                  SwitchListTile(
                    title: const Text(
                      '🎯 Smart Search (sort by proximity)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Show best matches first'),
                    value: _useProximitySearch,
                    onChanged: (value) {
                      setState(() {
                        _useProximitySearch = value;
                      });
                    },
                    activeColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _trainNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Train Number',
                      hintText: 'e.g., 12345',
                      prefixIcon: Icon(Icons.train),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter train number';
                      }
                      if (value.length < 5) {
                        return 'Train number must be at least 5 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _trainDateController,
                    decoration: const InputDecoration(
                      labelText: 'Train Date',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    readOnly: true,
                    onTap: _selectDate,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select train date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bogieController,
                    decoration: const InputDecoration(
                      labelText: 'Bogie (Optional)',
                      hintText: 'e.g., B3, A2',
                      prefixIcon: Icon(Icons.filter_alt),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  
                  // Proximity Search Fields (shown when toggle is on)
                  if (_useProximitySearch) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      '📍 Your Current & Desired Seats',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentBogieController,
                            decoration: const InputDecoration(
                              labelText: 'Your Bogie',
                              hintText: 'B3',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: _useProximitySearch
                                ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required for smart search';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _currentSeatController,
                            decoration: const InputDecoration(
                              labelText: 'Your Seat',
                              hintText: '45UB',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: _useProximitySearch
                                ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _desiredBogieController,
                            decoration: const InputDecoration(
                              labelText: 'Want Bogie',
                              hintText: 'A2',
                              prefixIcon: Icon(Icons.emoji_objects),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: _useProximitySearch
                                ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required for smart search';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _desiredSeatController,
                            decoration: const InputDecoration(
                              labelText: 'Want Seat',
                              hintText: '12LB',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: _useProximitySearch
                                ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
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
                      label: Text(_isLoading ? 'Searching...' : 'Search'),
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
          
          // Results
          Expanded(
            child: _buildResultsSection(),
          ),
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
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Enter train details to search',
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
              'Try searching for a different train or date',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                
                // Proximity Badge (if proximity search was used)
                if (hasProximity) ...[
                  const SizedBox(height: 8),
                  _buildProximityBadge(proximityDetails),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(entry['phone']),
                    icon: const Icon(Icons.phone),
                    label: Text('Call ${entry['phone']}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
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
    
    // Determine badge color and icon
    Color badgeColor;
    Color textColor;
    String icon;
    String label;
    
    switch (matchQuality) {
      case 'excellent':
        badgeColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = '🟢';
        label = 'Excellent Match';
        break;
      case 'good':
        badgeColor = Colors.lightGreen.shade100;
        textColor = Colors.lightGreen.shade900;
        icon = '🟡';
        label = 'Good Match';
        break;
      case 'fair':
        badgeColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = '🟠';
        label = 'Fair Match';
        break;
      default:
        badgeColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = '🔴';
        label = 'Poor Match';
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isSameBogie
                ? '📍 Same bogie • $seatDistance seats away'
                : '📍 $bogieDistance bogies away • $seatDistance seats',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
