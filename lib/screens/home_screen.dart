import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';
import '../services/signal_service.dart';
import '../services/server_manager.dart';
import '../services/account_service.dart';
import '../services/signal_client.dart';
import '../services/settings_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final Set<String> _selectedAccountIds = {};
  final Set<String> _selectedSignalIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _directionFilter; // BUY, SELL, null = all
  bool? _dailyFilter; // true, false, null = all
  DateTime? _selectedTradeDate;
  bool _isSendingSignals = false;
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimationController.forward();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TradeSignal> _getFilteredSignals() {
    final drafts = widget.signalService.signals.where((signal) => signal.isDraft).toList();
    return drafts.where((signal) {
      final matchesSearch = _searchQuery.isEmpty ||
          signal.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          signal.direction.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          signal.entryTime.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDirection =
          _directionFilter == null ? true : signal.direction == _directionFilter;
      final matchesDaily = _dailyFilter == null ? true : signal.isDaily == _dailyFilter;
      return matchesSearch && matchesDirection && matchesDaily;
    }).toList();
  }

  void _toggleSignalSelection(TradeSignal signal) {
    final id = signal.tradeId;
    if (id == null) return;
    setState(() {
      if (_selectedSignalIds.contains(id)) {
        _selectedSignalIds.remove(id);
      } else {
        _selectedSignalIds.add(id);
      }
    });
  }

  bool _isSignalSelected(TradeSignal signal) {
    final id = signal.tradeId;
    if (id == null) return false;
    return _selectedSignalIds.contains(id);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _directionFilter = null;
      _dailyFilter = null;
    });
  }

  Future<void> _showDeleteConfirmDialog(TradeSignal signal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Signal'),
        content: Text('Are you sure you want to delete "${signal.symbol}" ${signal.direction} signal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && signal.tradeId != null) {
      final deleted = await widget.signalService.deleteSignal(signal.tradeId!);
      if (deleted && mounted) {
        setState(() {
          _selectedSignalIds.remove(signal.tradeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signal deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  DateTime _getAdjustedEntryDateTime(TradeSignal signal) {
    DateTime original;
    try {
      original = DateFormat('yyyy-MM-dd HH:mm:ss').parse(signal.entryTime);
    } catch (_) {
      try {
        original = DateTime.parse(signal.entryTime);
      } catch (_) {
        original = signal.receivedAt;
      }
    }
    if (_selectedTradeDate == null) {
      return original;
    }
    return DateTime(
      _selectedTradeDate!.year,
      _selectedTradeDate!.month,
      _selectedTradeDate!.day,
      original.hour,
      original.minute,
      original.second,
    );
  }

  /// Adjust TP condition time by broker time offset
  /// TP conditions are in format "HH:MM" (e.g., "14:30")
  /// brokerTimeOffset is in format "-02:15" or "+03:00"
  /// Returns adjusted time in "HH:MM" format, or null if input is null
  String? _adjustTPTime(String? tpTime, String brokerTimeOffset) {
    if (tpTime == null || tpTime.isEmpty) return null;
    
    try {
      // Parse TP time (e.g., "14:30")
      final parts = tpTime.split(':');
      if (parts.length != 2) return tpTime; // Invalid format, return as-is
      
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      // Parse broker time offset (e.g., "-02:15" or "+03:00")
      bool isNegative = brokerTimeOffset.startsWith('-');
      final offsetStr = brokerTimeOffset.replaceAll(RegExp(r'[+-]'), '');
      final offsetParts = offsetStr.split(':');
      if (offsetParts.length != 2) return tpTime; // Invalid format, return as-is
      
      int offsetHours = int.parse(offsetParts[0]);
      int offsetMinutes = int.parse(offsetParts[1]);
      
      // Apply offset (subtract if negative, add if positive)
      // Note: brokerTimeOffset represents how much to DEDUCT from the time
      // So "-02:15" means subtract 2 hours 15 minutes
      if (isNegative) {
        // Subtract offset
        minute -= offsetMinutes;
        if (minute < 0) {
          minute += 60;
          hour -= 1;
        }
        hour -= offsetHours;
        if (hour < 0) {
          hour += 24; // Wrap around to previous day
        }
      } else {
        // Add offset
        minute += offsetMinutes;
        if (minute >= 60) {
          minute -= 60;
          hour += 1;
        }
        hour += offsetHours;
        if (hour >= 24) {
          hour -= 24; // Wrap around to next day
        }
      }
      
      // Format back to "HH:MM"
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // If parsing fails, return original time
      return tpTime;
    }
  }

  Future<void> _pickTradeDate() async {
    final initialDate = _selectedTradeDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedTradeDate = picked;
      });
    }
  }

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
          ? ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _fabAnimationController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _navigateToCreateSignal(),
                icon: const Icon(Icons.add),
                label: const Text('Create Signal'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            )
          : null,
    );
  }

  Future<void> _sendSelectedSignals() async {
    if (_selectedSignalIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one saved trade to send'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedAccountIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one forex account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingSignals = true);

    final settingsService = SettingsService();
    final remoteServerUrl = await settingsService.getRemoteServerUrl();

    String host;
    int port;
    String connectionType;
    bool useHttps = false;

    if (remoteServerUrl != null && remoteServerUrl.isNotEmpty) {
      final parsed = settingsService.parseServerUrl(remoteServerUrl);
      if (parsed == null) {
        setState(() => _isSendingSignals = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid remote server URL. Check Settings.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      host = parsed['host'] as String;
      port = parsed['port'] as int;
      connectionType = parsed['connectionType'] as String;
      useHttps = remoteServerUrl.startsWith('https://') || remoteServerUrl.startsWith('wss://');
    } else {
      if (!widget.serverManager.isRunning) {
        setState(() => _isSendingSignals = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No remote server configured and local server is not running.\nConfigure a server in Settings or start the local server.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      host = 'localhost';
      port = widget.serverManager.port;
      connectionType = widget.serverManager.connectionType;
    }

    final accounts = widget.accountService.accounts
        .where((a) => _selectedAccountIds.contains(a.id))
        .toList();

    final client = SignalClient(
      host: host,
      port: port,
      connectionType: connectionType,
      apiKey: await settingsService.getApiKey(),
      useHttps: useHttps,
    );

    final selectedSignals = widget.signalService.signals
        .where((signal) => signal.isDraft && signal.tradeId != null && _selectedSignalIds.contains(signal.tradeId))
        .toList();

    int successCount = 0;
    final List<String> errors = [];

    for (final signal in selectedSignals) {
      for (final account in accounts) {
        try {
          final adjustedEntry = _getAdjustedEntryDateTime(signal);
          // Apply broker time offset to TP conditions
          final adjustedTP1 = _adjustTPTime(signal.tpCondition1, account.brokerTimeOffset);
          final adjustedTP2 = _adjustTPTime(signal.tpCondition2, account.brokerTimeOffset);
          
          final payload = signal.copyWith(
            accountName: account.name,
            brand: account.brand,
            entryTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(adjustedEntry),
            // CRITICAL: Use signal.lot, NOT account.defaultLotSize
            lot: signal.lot,
            tpCondition1: adjustedTP1,
            tpCondition2: adjustedTP2,
            isDraft: false,
            receivedAt: DateTime.now(),
          );
          final response = await client.sendSignal(payload);
          if (response.status == 'success') {
            successCount++;
          } else {
            errors.add('${account.name}: ${response.message}');
          }
        } catch (e) {
          errors.add('${account.name}: ${e.toString()}');
        }
      }
    }

    setState(() {
      _isSendingSignals = false;
      _selectedSignalIds.clear();
    });

    if (!mounted) return;

    if (successCount > 0 && errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sent $successCount trade(s) to EA'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (successCount > 0 && errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Sent $successCount trade(s), ${errors.length} failed'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send trades: ${errors.join(", ")}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildSignalsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
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
                'Forex Dynamic',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                onPressed: () => setState(() => _currentIndex = 2),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTradeDateSelector(),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: 'Search saved trades',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _clearFilters,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      selected: _directionFilter == null && _dailyFilter == null,
                      onSelected: (_) => _clearFilters(),
                    ),
                    _buildFilterChip(
                      label: 'BUY',
                      selected: _directionFilter == 'BUY',
                      onSelected: (selected) =>
                          setState(() => _directionFilter = selected ? 'BUY' : null),
                    ),
                    _buildFilterChip(
                      label: 'SELL',
                      selected: _directionFilter == 'SELL',
                      onSelected: (selected) =>
                          setState(() => _directionFilter = selected ? 'SELL' : null),
                    ),
                    _buildFilterChip(
                      label: 'Daily Yes',
                      selected: _dailyFilter == true,
                      onSelected: (selected) =>
                          setState(() => _dailyFilter = selected ? true : null),
                    ),
                    _buildFilterChip(
                      label: 'Daily No',
                      selected: _dailyFilter == false,
                      onSelected: (selected) =>
                          setState(() => _dailyFilter = selected ? false : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<TradeSignal>(
            stream: widget.signalService.signalStream,
            builder: (context, snapshot) {
              final signals = _getFilteredSignals();
              if (signals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.save_alt,
                        size: 72,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved trades yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a signal to save it here',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: signals.length,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildSignalCard(signals[index]),
                  );
                },
              );
            },
          ),
        ),
        if (widget.signalService.signals.where((s) => s.isDraft).isNotEmpty)
          _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSignalCard(TradeSignal signal) {
    final isBuy = signal.direction == 'BUY';
    final isSelected = _isSignalSelected(signal);
    return GestureDetector(
      onTap: () => _toggleSignalSelection(signal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isBuy ? Colors.green.shade100 : Colors.red.shade100),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBuy ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    signal.direction,
                    style: TextStyle(
                      color: isBuy ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  signal.symbol,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateSignalScreen(
                          signalService: widget.signalService,
                          existingSignal: signal,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  onPressed: () => _showDeleteConfirmDialog(signal),
                  tooltip: 'Delete',
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignalDetailScreen(signal: signal),
                      ),
                    );
                  },
                  tooltip: 'View Details',
                ),
                const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.circle_outlined,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  'Entry',
                  DateFormat('yyyy.MM.dd HH:mm').format(_getAdjustedEntryDateTime(signal)),
                ),
                const SizedBox(width: 8),
                _buildInfoChip('Lot', signal.lot.toString()),
                const SizedBox(width: 8),
                _buildInfoChip('Daily', signal.isDaily ? 'Yes' : 'No'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMetric('TP', '${signal.tp}', Colors.green),
                _buildMetric('SL', '${signal.sl}', Colors.red),
                if (signal.newTP != null) _buildMetric('New TP', '${signal.newTP}', Colors.blue),
                if (signal.tpCondition1 != null)
                  _buildMetric('TP Time 1', signal.tpCondition1!, Colors.purple),
                if (signal.tpCondition2 != null)
                  _buildMetric('TP Time 2', signal.tpCondition2!, Colors.purple),
              ],
            ),
          ],
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedSignalIds.isEmpty
                      ? 'No trades selected'
                      : '${_selectedSignalIds.length} trade(s) selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_selectedSignalIds.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedSignalIds.clear());
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_selectedAccountIds.isEmpty ||
                      _selectedSignalIds.isEmpty ||
                      _isSendingSignals)
                  ? null
                  : _sendSelectedSignals,
              icon: _isSendingSignals
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _isSendingSignals ? 'Sending...' : 'Send Selected',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          signalService: widget.signalService,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeDateSelector() {
    final hasCustomDate = _selectedTradeDate != null;
    final displayText = hasCustomDate
        ? DateFormat('yyyy / MM / dd').format(_selectedTradeDate!)
        : 'Use saved entry dates';

    return Row(
      children: [
        IconButton(
          onPressed: _pickTradeDate,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          icon: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _pickTradeDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Text(
                    hasCustomDate ? displayText : 'Use saved entry dates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasCustomDate
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: 18),
                ],
              ),
            ),
          ),
        ),
        if (hasCustomDate)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: () => setState(() => _selectedTradeDate = null),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: onSelected,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
