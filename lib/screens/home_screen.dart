import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';
import '../services/signal_service.dart';
import '../services/server_manager.dart';
import '../services/account_service.dart';
import 'signal_detail_screen.dart';
import 'create_signal_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final SignalService signalService;
  final ServerManager serverManager;
  final AccountService accountService;

  const HomeScreen({
    super.key,
    required this.signalService,
    required this.serverManager,
    required this.accountService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<String> _selectedAccountIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildSignalsTab(),
          _buildServerTab(),
          _buildSettingsTab(),
          _buildAccountsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            label: 'Signals',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns),
            label: 'Server',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance),
            label: 'Accounts',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToCreateSignal(),
              icon: const Icon(Icons.add),
              label: const Text('Create Signal'),
            )
          : null,
    );
  }

  Widget _buildSignalsTab() {
    return Column(
      children: [
        // App Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text(
                'Trade Signals',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => setState(() => _currentIndex = 1),
              ),
            ],
          ),
        ),

        // Signal Cards
        Expanded(
          child: StreamBuilder<TradeSignal>(
            stream: widget.signalService.signalStream,
            builder: (context, snapshot) {
              final signals = widget.signalService.signals;
              if (signals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No signals yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first trade signal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: signals.length,
                itemBuilder: (context, index) {
                  return _buildSignalCard(signals[index]);
                },
              );
            },
          ),
        ),

        // Account Selection & Send Button
        if (widget.signalService.signals.isNotEmpty) _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSignalCard(TradeSignal signal) {
    final isBuy = signal.direction == 'BUY';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBuy ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignalDetailScreen(signal: signal),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isBuy ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    signal.direction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.symbol,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${signal.direction} • Lot: ${signal.lot}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'TP: ${signal.tp} pips • SL: ${signal.sl} pips',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    signal.accountName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, HH:mm').format(signal.receivedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Account Selection Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAccountSelection(),
              icon: const Icon(Icons.account_balance_wallet),
              label: Text(
                _selectedAccountIds.isEmpty
                    ? 'Select Accounts'
                    : '${_selectedAccountIds.length} Account(s) Selected',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Send Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _selectedAccountIds.isEmpty ? null : () => _navigateToCreateSignal(),
              icon: const Icon(Icons.send),
              label: const Text(
                'Send Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerTab() {
    int _selectedPort = widget.serverManager.port;
    String _selectedConnectionType = widget.serverManager.connectionType;
    final _portController = TextEditingController(text: _selectedPort.toString());
    final _apiKeyController = TextEditingController();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.serverManager.isRunning
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: widget.serverManager.isRunning
                          ? Colors.green
                          : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.serverManager.isRunning
                          ? 'Server Running'
                          : 'Server Stopped',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.serverManager.isRunning) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow('Port', widget.serverManager.port.toString()),
                  _buildInfoRow('Type', widget.serverManager.connectionType),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !widget.serverManager.isRunning,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedConnectionType,
                  decoration: const InputDecoration(
                    labelText: 'Connection Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'REST', child: Text('REST API')),
                    DropdownMenuItem(value: 'WebSocket', child: Text('WebSocket')),
                    DropdownMenuItem(value: 'TCP', child: Text('TCP Socket')),
                  ],
                  onChanged: widget.serverManager.isRunning
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedConnectionType = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Leave empty for no authentication',
                  ),
                  obscureText: true,
                  enabled: !widget.serverManager.isRunning,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (widget.serverManager.isRunning) {
                        await widget.serverManager.stopServer();
                      } else {
                        try {
                          final port = int.tryParse(_portController.text) ?? 8080;
                          if (port < 1024 || port > 65535) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Port must be between 1024 and 65535')),
                              );
                            }
                            return;
                          }
                          await widget.serverManager.startServer(
                            port: port,
                            connectionType: _selectedConnectionType,
                            apiKey: _apiKeyController.text.isEmpty
                                ? null
                                : _apiKeyController.text,
                          );
                          
                          // Test local connection
                          await Future.delayed(const Duration(milliseconds: 500));
                          final isWorking = await widget.serverManager.testLocalConnection();
                          
                          if (mounted) {
                            if (isWorking) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Server started and responding!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Server started but not responding. Check console for errors.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Failed to start server: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                          print('Server start error: $e');
                        }
                      }
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.serverManager.isRunning
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      widget.serverManager.isRunning
                          ? 'Stop Server'
                          : 'Start Server',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return const SettingsScreen();
  }

  Widget _buildAccountsTab() {
    return AccountsScreen(accountService: widget.accountService);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Accounts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.accountService.accounts.map((account) {
              return CheckboxListTile(
                title: Text(account.name),
                subtitle: Text(account.brand),
                value: _selectedAccountIds.contains(account.id),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selectedAccountIds.add(account.id);
                    } else {
                      _selectedAccountIds.remove(account.id);
                    }
                  });
                },
                secondary: CircleAvatar(
                  backgroundColor: Color(account.colorValue),
                  child: Text(
                    account.name[0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateSignal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSignalScreen(
          accountService: widget.accountService,
          signalService: widget.signalService,
          serverManager: widget.serverManager,
          selectedAccountIds: _selectedAccountIds.toList(),
        ),
      ),
    );
  }
}
