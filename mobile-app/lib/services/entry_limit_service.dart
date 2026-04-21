import 'package:shared_preferences/shared_preferences.dart';

/// Device-based entry limit tracking
/// Limit: 10 entries per app installation
/// Can be reset by uninstalling and reinstalling the app
class EntryLimitService {
  static const String _keyEntriesUsed = 'entries_used';
  static const int maxEntries = 10;

  /// Get number of entries used on this device
  Future<int> getEntriesUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyEntriesUsed) ?? 0;
  }

  /// Get remaining entries on this device
  Future<int> getRemainingEntries() async {
    final used = await getEntriesUsed();
    return maxEntries - used;
  }

  /// Check if user can create more entries
  Future<bool> canCreateEntry() async {
    final used = await getEntriesUsed();
    return used < maxEntries;
  }

  /// Increment entry count (call after successful entry creation)
  Future<int> incrementEntryCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyEntriesUsed) ?? 0;
    final newCount = current + 1;
    await prefs.setInt(_keyEntriesUsed, newCount);
    return newCount;
  }

  /// Check if limit is reached
  Future<bool> isLimitReached() async {
    final used = await getEntriesUsed();
    return used >= maxEntries;
  }

  /// Reset counter (for testing only - user would reinstall app)
  Future<void> resetCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEntriesUsed);
  }
}
