import 'package:shared_preferences/shared_preferences.dart';

// Storage implementation - works in Flutter, gracefully fails in server
Future<String?> getStoredSignals(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  } catch (_) {
    // Running in server environment or error - no persistence available
    return null;
  }
}

Future<void> saveSignals(String key, String value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  } catch (_) {
    // Silently fail in server environment - no persistence available
    // Server doesn't need persistence anyway
  }
}

