import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _serverUrlKey = 'remote_server_url';
  static const String _connectionTypeKey = 'remote_connection_type';
  static const String _apiKeyKey = 'remote_api_key';

  // Get remote server URL
  Future<String?> getRemoteServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to the Render server if not set
    return prefs.getString(_serverUrlKey) ?? 'https://forex-dynamic.onrender.com';
  }

  // Set remote server URL
  Future<void> setRemoteServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  // Get connection type
  Future<String> getConnectionType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_connectionTypeKey) ?? 'REST';
  }

  // Set connection type
  Future<void> setConnectionType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionTypeKey, type);
  }

  // Get API key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  // Set API key
  Future<void> setApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, key);
    }
  }

  // Parse URL to extract host and port
  Map<String, dynamic>? parseServerUrl(String url) {
    try {
      // Remove trailing slash
      url = url.trim();
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      Uri uri;
      if (url.startsWith('http://') || url.startsWith('https://') || 
          url.startsWith('ws://') || url.startsWith('wss://')) {
        uri = Uri.parse(url);
      } else {
        // Assume http if no protocol
        uri = Uri.parse('http://$url');
      }

      String host = uri.host;
      int port = uri.port;
      if (port == 0) {
        port = uri.scheme == 'https' || uri.scheme == 'wss' ? 443 : 80;
      }

      String connectionType = 'REST';
      if (uri.scheme == 'ws' || uri.scheme == 'wss') {
        connectionType = 'WebSocket';
      } else if (uri.scheme == 'tcp' || uri.scheme == 'tcp://') {
        connectionType = 'TCP';
      }

      return {
        'host': host,
        'port': port,
        'connectionType': connectionType,
        'url': url,
      };
    } catch (e) {
      return null;
    }
  }
}

