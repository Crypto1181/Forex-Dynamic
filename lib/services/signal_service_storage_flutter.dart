import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getStoredSignals(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  } catch (_) {
    return null;
  }
}

Future<void> saveSignals(String key, String value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  } catch (_) {
    // ignore errors
  }
}
