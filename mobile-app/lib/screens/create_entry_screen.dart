import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/entry_limit_service.dart';
import '../models/seat_entry.dart';

class CreateEntryScreen extends StatefulWidget {
  final String phone;
  
  const CreateEntryScreen({
    super.key,
    required this.phone,
  });

  @override
  State<CreateEntryScreen> createState() => _CreateEntryScreenState();
}

class _CreateEntryScreenState extends State<CreateEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final EntryLimitService _limitService = EntryLimitService();
  
  // Controllers
  final _pnrController = TextEditingController();
  final _trainNumberController = TextEditingController();
  final _trainDateController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _currentBogieController = TextEditingController();
  final _currentSeatController = TextEditingController();
  final _desiredBogieController = TextEditingController();
  final _desiredSeatController = TextEditingController();
  
  bool _isLoading = false;
  bool _pnrVerified = false;
  int _remainingEntries = 10;

  @override
  void initState() {
    super.initState();
    _checkRemainingEntries();
  }

  @override
  void dispose() {
    _pnrController.dispose();
    _trainNumberController.dispose();
    _trainDateController.dispose();
    _departureTimeController.dispose();
    _currentBogieController.dispose();
    _currentSeatController.dispose();
    _desiredBogieController.dispose();
    _desiredSeatController.dispose();
    super.dispose();
  }

  Future<void> _checkRemainingEntries() async {
    try {
      final remaining = await _limitService.getRemainingEntries();
      setState(() {
        _remainingEntries = remaining;
      });
      
      // Show limit reached dialog if no entries left
      if (remaining <= 0 && mounted) {
        _showLimitReachedDialog();
      }
    } catch (e) {
      // Ignore error, will show default
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Entry Limit Reached'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have used all 10 entries included with your purchase.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Need more entries?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Uninstall this app\n'
              '2. Reinstall from Play Store\n'
              '3. Purchase again for ₹500\n'
              '4. Get 10 more entries!',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Note: You can still search for seat exchanges without creating new entries.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkRemainingEntries() async {
    try {
      final limits = await _apiService.getUserLimits(widget.phone);
      setState(() {
        _remainingEntries = limits['remaining_entries'] ?? 0;
      });
    } catch (e) {
      // Ignore error, will show default
    }
  }

  Future<void> _verifyPNR() async {
    if (_pnrController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNR must be 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.verifyPNR(_pnrController.text.trim());
      
      if (result['success'] == true) {
        setState(() {
          _trainNumberController.text = result['train_number'] ?? '';
          _trainDateController.text = result['date_of_journey'] ?? '';
          _currentBogieController.text = result['bogie'] ?? '';
          _currentSeatController.text = result['seat_number'] ?? '';
          _pnrVerified = true;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PNR verified! Details auto-filled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'PNR verification failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() {
        _departureTimeController.text = 
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submitEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check device-based limit
    final canCreate = await _limitService.canCreateEntry();
    if (!canCreate) {
      _showLimitReachedDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final entry = SeatEntry(
        phone: widget.phone,
        trainNumber: _trainNumberController.text.trim(),
        trainDate: _trainDateController.text.trim(),
        departureTime: _departureTimeController.text.trim(),
        currentBogie: _currentBogieController.text.trim().toUpperCase(),
        currentSeat: _currentSeatController.text.trim(),
        desiredBogie: _desiredBogieController.text.trim().toUpperCase(),
        desiredSeat: _desiredSeatController.text.trim(),
      );

      final result = await _apiService.createEntry(entry: entry);

      if (result['success'] == true) {
        // Increment local counter
        final newCount = await _limitService.incrementEntryCount();
        final remaining = await _limitService.getRemainingEntries();
        
        setState(() {
          _isLoading = false;
          _remainingEntries = remaining;
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('✅ Entry Created!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your seat exchange request is now live.'),
                  const SizedBox(height: 12),
                  Text(
                    'Entries used: $newCount/10',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Remaining: $remaining',
                    style: TextStyle(
                      color: remaining > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (remaining == 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '💡 All entries used! Uninstall and reinstall to get 10 more entries for ₹500.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close entry screen
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Entry creation failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
        title: const Text('Create Exchange Entry'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remaining Entries Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _remainingEntries > 0 
                      ? Colors.green.shade50 
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _remainingEntries > 0 
                        ? Colors.green 
                        : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _remainingEntries > 0 
                          ? Icons.check_circle 
                          : Icons.warning,
                      color: _remainingEntries > 0 
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have $_remainingEntries of 10 entries remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _remainingEntries > 0 
                              ? Colors.green.shade900 
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // PNR Verification (Optional)
              const Text(
                'PNR Verification (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pnrController,
                      decoration: const InputDecoration(
                        labelText: '10-digit PNR',
                        hintText: '1234567890',
                        prefixIcon: Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      enabled: !_pnrVerified,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pnrVerified ? null : _verifyPNR,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    child: _pnrVerified
                        ? const Icon(Icons.check, color: Colors.green)
                        : const Text('Verify'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Train Details
              const Text(
                'Train Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trainNumberController,
                decoration: const InputDecoration(
                  labelText: 'Train Number *',
                  hintText: '12345',
                  prefixIcon: Icon(Icons.train),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (value.length < 5) {
                    return 'Must be at least 5 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trainDateController,
                decoration: const InputDecoration(
                  labelText: 'Train Date *',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departureTimeController,
                decoration: const InputDecoration(
                  labelText: 'Departure Time *',
                  hintText: 'HH:MM',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _selectTime,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Current Seat
              const Text(
                'Current Seat (What You Have)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _currentBogieController,
                      decoration: const InputDecoration(
                        labelText: 'Bogie *',
                        hintText: 'B3, A2',
                        prefixIcon: Icon(Icons.directions_railway),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currentSeatController,
                      decoration: const InputDecoration(
                        labelText: 'Seat *',
                        hintText: '45',
                        prefixIcon: Icon(Icons.event_seat),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Desired Seat
              const Text(
                'Desired Seat (What You Want)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _desiredBogieController,
                      decoration: const InputDecoration(
                        labelText: 'Bogie *',
                        hintText: 'A2, C1',
                        prefixIcon: Icon(Icons.directions_railway),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _desiredSeatController,
                      decoration: const InputDecoration(
                        labelText: 'Seat *',
                        hintText: 'Near 12',
                        prefixIcon: Icon(Icons.event_seat),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Entry',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Info Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ℹ️ Important',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Entry will be visible to all users\n'
                      '• Others can call you to arrange exchange\n'
                      '• Entry auto-deletes 2 hours after departure\n'
                      '• One entry per train allowed',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
