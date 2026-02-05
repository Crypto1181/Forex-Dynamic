import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _settingsService = SettingsService();
  final _serverUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  String _connectionType = 'REST';
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    _animationController.forward();
  }

  Future<void> _saveSettings() async {
    String url = _serverUrlController.text.trim();
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter server URL'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (url.startsWith(':')) {
      url = url.substring(1).trim();
    }
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('ngrok')) {
        url = 'https://$url';
      } else {
        url = 'http://$url';
      }
    }

    final parsed = _settingsService.parseServerUrl(url);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Invalid server URL format. Please include https://'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Settings saved successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter server URL first'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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

      String testUrl = url.trim();
      
      if (testUrl.startsWith(':')) {
        testUrl = testUrl.substring(1);
      }
      
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        if (testUrl.contains('ngrok')) {
          testUrl = 'https://$testUrl';
        } else {
          testUrl = 'http://$testUrl';
        }
      }
      
      testUrl = testUrl.replaceAll(RegExp(r'/$'), '');
      
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
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
        ),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Remote Server Configuration',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFf8fafc),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
                      padding: const EdgeInsets.all(20),
            children: [
              // Header Card
                        Container(
                          padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                            borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                                padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                                  Icons.cloud_upload_rounded,
                          color: Colors.white,
                                  size: 32,
                        ),
                      ),
                              const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remote Server',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configure server connection',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                        const SizedBox(height: 24),

              // Server URL
                        _buildModernInputCard(
                          icon: Icons.link_rounded,
                          label: 'Server URL',
                          child: TextField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://forex-dynamic.onrender.com',
                              prefixIcon: const Icon(Icons.language_rounded),
                        border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                        ),
                        filled: true,
                              fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 16),

              // Connection Type
                        _buildModernInputCard(
                          icon: Icons.settings_ethernet_rounded,
                          label: 'Connection Type',
                          child: DropdownButtonFormField<String>(
                      value: _connectionType,
                      decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.api_rounded),
                        border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                        ),
                        filled: true,
                              fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'REST',
                          child: Row(
                            children: [
                                    Icon(Icons.http_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('REST API'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'WebSocket',
                          child: Row(
                            children: [
                                    Icon(Icons.sync_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('WebSocket'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'TCP',
                          child: Row(
                            children: [
                                    Icon(Icons.cable_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('TCP Socket'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _connectionType = value);
                        }
                      },
                ),
              ),
              const SizedBox(height: 16),

              // API Key
                        _buildModernInputCard(
                          icon: Icons.vpn_key_rounded,
                          label: 'API Key (Optional)',
                          child: TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                              hintText: 'Leave empty for no authentication',
                              prefixIcon: const Icon(Icons.lock_rounded),
                        border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                        ),
                        filled: true,
                              fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      obscureText: true,
                ),
              ),
              const SizedBox(height: 24),

              // Test Connection Result
              if (_testResult != null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _testResult!.contains('successful')
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _testResult!.contains('successful')
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        width: 2,
                      ),
                    ),
                    child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _testResult!.contains('successful')
                                      ? Icons.check_circle_rounded
                                      : Icons.error_rounded,
                          color: _testResult!.contains('successful')
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                                  size: 28,
                        ),
                                const SizedBox(width: 16),
                        Expanded(
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
                    ),
                  ),

              // Action Buttons
                        Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                              height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                    : const Icon(Icons.wifi_find_rounded),
                        label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                              height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                                icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                          ),
                                  elevation: 4,
                        ),
                      ),
                    ),
                  ],
              ),
              const SizedBox(height: 16),
            ],
          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInputCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
