// Stub storage for server environment - no persistence
Future<String?> getStoredSignals(String key) async {
  return null;
}

Future<void> saveSignals(String key, String value) async {
  // no-op on server
}
