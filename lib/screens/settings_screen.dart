import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _serverUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  String _connectionType = 'REST';
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final url = await _settingsService.getRemoteServerUrl();
    final apiKey = await _settingsService.getApiKey();
    final connectionType = await _settingsService.getConnectionType();

    _serverUrlController.text = url ?? '';
    _apiKeyController.text = apiKey ?? '';
    _connectionType = connectionType;

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    String url = _serverUrlController.text.trim();
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter server URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fix common URL issues
    // Remove leading colon if present
    if (url.startsWith(':')) {
      url = url.substring(1).trim();
    }
    
    // Add https:// if missing (for ngrok URLs)
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('ngrok')) {
        url = 'https://$url';
      } else {
        url = 'http://$url';
      }
    }

    // Validate URL
    final parsed = _settingsService.parseServerUrl(url);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid server URL format. Please include https://'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _settingsService.setRemoteServerUrl(url);
    await _settingsService.setConnectionType(_connectionType);
    await _settingsService.setApiKey(
      _apiKeyController.text.trim().isEmpty 
          ? null 
          : _apiKeyController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter server URL first')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final parsed = _settingsService.parseServerUrl(url);
      if (parsed == null) {
        setState(() {
          _testResult = 'Invalid URL format';
          _isTesting = false;
        });
        return;
      }

      // Test connection with GET request to root endpoint
      String testUrl = url.trim();
      
      // Fix common issues
      // Remove leading colon if present (from copy-paste errors)
      if (testUrl.startsWith(':')) {
        testUrl = testUrl.substring(1);
      }
      
      // Add https:// if missing
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        // For ngrok URLs, use https
        if (testUrl.contains('ngrok')) {
          testUrl = 'https://$testUrl';
        } else {
          testUrl = 'http://$testUrl';
        }
      }
      
      // Remove trailing slash
      testUrl = testUrl.replaceAll(RegExp(r'/$'), '');
      
      // Validate URL format
      try {
        final uri = Uri.parse(testUrl);
        if (uri.host.isEmpty) {
          setState(() {
            _testResult = 'Invalid URL format. Please check the URL.';
            _isTesting = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _testResult = 'Invalid URL format: ${e.toString()}';
          _isTesting = false;
        });
        return;
      }
      
      final uri = Uri.parse(testUrl);
      
      // Add headers for ngrok free tier (may require browser warning bypass)
      final headers = {
        'User-Agent': 'Flutter-App/1.0',
        'Accept': 'application/json',
      };
      
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        setState(() {
          _testResult = 'Connection successful! Server is running.';
          _isTesting = false;
        });
      } else {
        setState(() {
          _testResult = 'Server responded with status: ${response.statusCode}';
          _isTesting = false;
        });
      }
    } catch (e) {
      setState(() {
        String errorMsg = e.toString();
        if (errorMsg.contains('timeout') || errorMsg.contains('Timeout') || errorMsg.contains('Future not completed')) {
          _testResult = 'Connection timeout (15s).\n\nCheck:\n1. Server running (Server tab → Start Server)\n2. ngrok running (terminal: ngrok http 8080)\n3. Both devices have internet\n4. Try accessing URL in browser first';
        } else {
          _testResult = 'Connection failed: ${e.toString()}\n\nMake sure:\n- Server is running on laptop\n- ngrok is running\n- URL is correct';
        }
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remote Server Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your laptop server URL. Signals will be sent to this server.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://abc123.ngrok.io:8080',
                      border: OutlineInputBorder(),
                      helperText: 'Enter full URL including https:// (e.g., https://nonstabile-renee-snippily.ngrok-free.dev:8080)',
                      prefixText: 'https://',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _connectionType,
                    decoration: const InputDecoration(
                      labelText: 'Connection Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'REST', child: Text('REST API')),
                      DropdownMenuItem(value: 'WebSocket', child: Text('WebSocket')),
                      DropdownMenuItem(value: 'TCP', child: Text('TCP Socket')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _connectionType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key (Optional)',
                      hintText: 'Leave empty if no authentication',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isTesting ? null : _testConnection,
                          child: _isTesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult!.contains('successful')
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testResult!.contains('successful')
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to Get Server URL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Option 1: Using ngrok (for remote access)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Install ngrok: https://ngrok.com'),
                  const Text('2. On laptop, run: ngrok http 8080'),
                  const Text('3. Copy the URL (e.g., https://abc123.ngrok.io)'),
                  const Text('4. Add port: https://abc123.ngrok.io:8080'),
                  const SizedBox(height: 16),
                  const Text(
                    'Option 2: Local IP (same WiFi)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Find laptop IP: ipconfig (Windows) or ifconfig (Mac/Linux)'),
                  const Text('2. Use: http://192.168.1.100:8080 (your IP)'),
                  const SizedBox(height: 16),
                  const Text(
                    'Note:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const Text(
                    'Share the same URL with EA builders so they can connect their EAs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

