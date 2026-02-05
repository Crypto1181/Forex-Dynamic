import 'dart:ui';
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
  String? _directionFilter;
  bool? _dailyFilter;
  DateTime? _selectedTradeDate;
  bool _isSendingSignals = false;
  bool _isCardView = true; // true for card view, false for list view
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
    final drafts = widget.signalService.signals
        .where((signal) => signal.isDraft)
        .toList();
    return drafts.where((signal) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          signal.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          signal.direction.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          signal.entryTime.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDirection = _directionFilter == null
          ? true
          : signal.direction == _directionFilter;
      final matchesDaily = _dailyFilter == null
          ? true
          : signal.isDaily == _dailyFilter;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Signal'),
        content: Text(
          'Are you sure you want to delete "${signal.symbol}" ${signal.direction} signal?\n\nThis will remove it from the app and attempt to cancel it on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete & Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && signal.tradeId != null) {
      // 1. Try to delete from Server (Cancel Signal)
      final settingsService = SettingsService();
      final remoteServerUrl = await settingsService.getRemoteServerUrl();

      String host;
      int port;
      String connectionType;
      bool useHttps = false;

      if (remoteServerUrl != null && remoteServerUrl.isNotEmpty) {
        final parsed = settingsService.parseServerUrl(remoteServerUrl);
        if (parsed != null) {
          host = parsed['host'] as String;
          port = parsed['port'] as int;
          connectionType = parsed['connectionType'] as String;
          useHttps =
              remoteServerUrl.startsWith('https://') ||
              remoteServerUrl.startsWith('wss://');

          final client = SignalClient(
            host: host,
            port: port,
            connectionType: connectionType,
            apiKey: await settingsService.getApiKey(),
            useHttps: useHttps,
          );

          try {
            final response = await client.deleteSignal(signal.tradeId!);
            if (response.status == 'success') {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signal cancelled on server'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to cancel on server: ${response.message}',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error cancelling signal on server: $e');
            // Continue to delete locally even if server fails
          }
        }
      }

      // 2. Delete locally and from Supabase
      final deleted = await widget.signalService.deleteSignal(signal.tradeId!);
      if (deleted && mounted) {
        setState(() {
          _selectedSignalIds.remove(signal.tradeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signal deleted from app'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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

  String? _adjustTPTime(String? tpTime, String brokerTimeOffset) {
    if (tpTime == null || tpTime.isEmpty) return null;

    try {
      final parts = tpTime.split(':');
      if (parts.length != 2) return tpTime;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      bool isNegative = brokerTimeOffset.startsWith('-');
      final offsetStr = brokerTimeOffset.replaceAll(RegExp(r'[+-]'), '');
      final offsetParts = offsetStr.split(':');
      if (offsetParts.length != 2) return tpTime;

      int offsetHours = int.parse(offsetParts[0]);
      int offsetMinutes = int.parse(offsetParts[1]);

      if (isNegative) {
        minute -= offsetMinutes;
        if (minute < 0) {
          minute += 60;
          hour -= 1;
        }
        hour -= offsetHours;
        if (hour < 0) {
          hour += 24;
        }
      } else {
        minute += offsetMinutes;
        if (minute >= 60) {
          minute -= 60;
          hour += 1;
        }
        hour += offsetHours;
        if (hour >= 24) {
          hour -= 24;
        }
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.trending_up, color: Colors.grey[600]),
              selectedIcon: Icon(
                Icons.trending_up,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Signals',
            ),
            NavigationDestination(
              icon: Icon(Icons.dns, color: Colors.grey[600]),
              selectedIcon: Icon(
                Icons.dns,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Server',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings, color: Colors.grey[600]),
              selectedIcon: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance, color: Colors.grey[600]),
              selectedIcon: Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Accounts',
            ),
          ],
        ),
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
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create Signal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 8,
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
      useHttps =
          remoteServerUrl.startsWith('https://') ||
          remoteServerUrl.startsWith('wss://');
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
        .where(
          (signal) =>
              signal.isDraft &&
              signal.tradeId != null &&
              _selectedSignalIds.contains(signal.tradeId),
        )
        .toList();

    int successCount = 0;
    final List<String> errors = [];

    for (final signal in selectedSignals) {
      for (final account in accounts) {
        try {
          final adjustedEntry = _getAdjustedEntryDateTime(signal);
          final adjustedTP1 = _adjustTPTime(
            signal.tpCondition1,
            account.brokerTimeOffset,
          );
          final adjustedTP2 = _adjustTPTime(
            signal.tpCondition2,
            account.brokerTimeOffset,
          );

          final payload = signal.copyWith(
            accountName: account.name,
            brand: account.brand,
            entryTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(adjustedEntry),
            lot: signal.lot > 0 ? signal.lot : account.defaultLotSize,
            dailyLot: signal.isDaily 
                ? (signal.dailyLot != null && signal.dailyLot! > 0 ? signal.dailyLot : account.defaultDailyLot) 
                : null,
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
          content: Text(
            '⚠️ Sent $successCount trade(s), ${errors.length} failed',
          ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Minimal Header - max space for 6 cards
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Forex Dynamic',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filters Section
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFf8fafc),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Column(
                        children: [
                          _buildTradeDateSelector(),
                          const SizedBox(height: 6),
                          // Search - minimal height
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Colors.grey[600],
                                  size: 18,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          color: Colors.grey[600],
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _clearFilters,
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // View Toggle and Filter Chips Row
                          Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildModernFilterChip(
                                        label: 'All',
                                        icon: Icons.filter_list_rounded,
                                        selected:
                                            _directionFilter == null &&
                                            _dailyFilter == null,
                                        onSelected: (_) => _clearFilters(),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildModernFilterChip(
                                        label: 'BUY',
                                        icon: Icons.trending_up_rounded,
                                        selected: _directionFilter == 'BUY',
                                        onSelected: (selected) => setState(
                                          () => _directionFilter = selected
                                              ? 'BUY'
                                              : null,
                                        ),
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      _buildModernFilterChip(
                                        label: 'SELL',
                                        icon: Icons.trending_down_rounded,
                                        selected: _directionFilter == 'SELL',
                                        onSelected: (selected) => setState(
                                          () => _directionFilter = selected
                                              ? 'SELL'
                                              : null,
                                        ),
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      _buildModernFilterChip(
                                        label: 'Daily',
                                        icon: Icons.repeat_rounded,
                                        selected: _dailyFilter == true,
                                        onSelected: (selected) => setState(
                                          () => _dailyFilter = selected
                                              ? true
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // View Toggle
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildViewToggleButton(
                                      icon: Icons.view_list_rounded,
                                      isSelected: !_isCardView,
                                      onTap: () =>
                                          setState(() => _isCardView = false),
                                    ),
                                    _buildViewToggleButton(
                                      icon: Icons.grid_view_rounded,
                                      isSelected: _isCardView,
                                      onTap: () =>
                                          setState(() => _isCardView = true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Signals List
                    Expanded(
                      child: StreamBuilder<TradeSignal>(
                        stream: widget.signalService.signalStream,
                        builder: (context, snapshot) {
                          final signals = _getFilteredSignals();
                          if (signals.isEmpty) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFf8fafc),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.elasticOut,
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Container(
                                            padding: const EdgeInsets.all(32),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(
                                                    0xFF667eea,
                                                  ).withOpacity(0.1),
                                                  const Color(
                                                    0xFF764ba2,
                                                  ).withOpacity(0.05),
                                                ],
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.analytics_outlined,
                                              size: 80,
                                              color: const Color(0xFF667eea),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    const Text(
                                      'No Signals Yet',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0f172a),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create your first trading signal',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (_isCardView) {
                            // Card View (Grid) - 6 cards visible without scroll (3 rows x 2 cols)
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                4,
                                10,
                                100,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.88,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                  ),
                              itemCount: signals.length,
                              itemBuilder: (context, index) {
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 300 + (index * 50),
                                  ),
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
                                  child: _buildCardViewSignal(signals[index]),
                                );
                              },
                            );
                          } else {
                            // List View
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: signals.length,
                              itemBuilder: (context, index) {
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 300 + (index * 50),
                                  ),
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
                                  child: _buildModernSignalCard(signals[index]),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar - Only shows when signals are selected
            _buildModernBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSignalCard(TradeSignal signal) {
    final isBuy = signal.direction == 'BUY';
    final isSelected = _isSignalSelected(signal);
    final gradientColors = isBuy
        ? [const Color(0xFF10b981), const Color(0xFF059669)]
        : [const Color(0xFFef4444), const Color(0xFFdc2626)];

    return GestureDetector(
      onTap: () => _toggleSignalSelection(signal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    gradientColors[0].withOpacity(0.15),
                    gradientColors[1].withOpacity(0.1),
                  ]
                : [Colors.white, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? gradientColors[0] : Colors.grey[200]!,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? gradientColors[0].withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Direction Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: gradientColors[0].withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBuy
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              signal.direction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Entry Type Badge (New)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          signal.entryType == 'PRICE' ? 'PRICE' : 'TIME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Symbol - Fixed to display horizontally
                      Expanded(
                        child: Text(
                          signal.symbol,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0f172a),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Action Buttons - Improved Layout
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateSignalScreen(
                                  signalService: widget.signalService,
                                  existingSignal: signal,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          } else if (value == 'delete') {
                            _showDeleteConfirmDialog(signal);
                          } else if (value == 'view') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SignalDetailScreen(signal: signal),
                              ),
                            );
                          } else if (value == 'duplicate') {
                            widget.signalService.duplicateSignal(signal);
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Duplicated "${signal.symbol}" ${signal.direction}',
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  color: Colors.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Duplicate'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('View Details'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Selection Indicator
                      GestureDetector(
                        onTap: () => _toggleSignalSelection(signal),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? gradientColors[0]
                                : Colors.grey[200],
                            border: Border.all(
                              color: isSelected
                                  ? gradientColors[0]
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Key Info Row (Lot & Daily in account settings)
                  _buildInfoChip(
                    icon: signal.entryType == 'PRICE'
                        ? Icons.attach_money_rounded
                        : Icons.access_time_rounded,
                    label: signal.entryType == 'PRICE'
                        ? 'Entry Price'
                        : 'Entry Time',
                    value: signal.entryType == 'PRICE'
                        ? '${signal.entryPrice}'
                        : DateFormat(
                            'MM.dd HH:mm',
                          ).format(_getAdjustedEntryDateTime(signal)),
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  // Metrics Row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricChip(
                        icon: Icons.trending_up_rounded,
                        label: 'TP',
                        value: '${signal.tp}',
                        color: Colors.green,
                      ),
                      _buildMetricChip(
                        icon: Icons.trending_down_rounded,
                        label: 'SL',
                        value: '${signal.sl}',
                        color: Colors.red,
                      ),
                      if (signal.newTP != null)
                        _buildMetricChip(
                          icon: Icons.edit_rounded,
                          label: 'New TP',
                          value: '${signal.newTP}',
                          color: Colors.blue,
                        ),
                      if (signal.tpCondition1 != null)
                        _buildMetricChip(
                          icon: Icons.schedule_rounded,
                          label: 'TP Time 1',
                          value: signal.tpCondition1!,
                          color: Colors.purple,
                        ),
                      if (signal.tpCondition2 != null)
                        _buildMetricChip(
                          icon: Icons.schedule_rounded,
                          label: 'TP Time 2',
                          value: signal.tpCondition2!,
                          color: Colors.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCardViewSignal(TradeSignal signal) {
    final isBuy = signal.direction == 'BUY';
    final isSelected = _isSignalSelected(signal);

    return GestureDetector(
      onTap: () => _toggleSignalSelection(signal),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isBuy ? Colors.green : Colors.red)
                : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header accent
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: isBuy ? Colors.green : Colors.red,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Symbol and Direction Row
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: (isBuy ? Colors.green : Colors.red)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                signal.symbol.isNotEmpty
                                    ? signal.symbol.substring(0, 1)
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isBuy ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        signal.symbol,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0f172a),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (signal.entryType == 'PRICE')
                                      Container(
                                        margin: const EdgeInsets.only(left: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                        child: const Text(
                                          'P',
                                          style: TextStyle(
                                            fontSize: 6,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBuy
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    signal.direction,
                                    style: TextStyle(
                                      fontSize: 6,
                                      fontWeight: FontWeight.bold,
                                      color: isBuy ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.grey[600],
                              size: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateSignalScreen(
                                      signalService: widget.signalService,
                                      existingSignal: signal,
                                    ),
                                  ),
                                ).then((_) => setState(() {}));
                              } else if (value == 'delete') {
                                _showDeleteConfirmDialog(signal);
                              } else if (value == 'view') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SignalDetailScreen(signal: signal),
                                  ),
                                );
                              } else if (value == 'duplicate') {
                                widget.signalService.duplicateSignal(signal);
                                setState(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Duplicated "${signal.symbol}" ${signal.direction}',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Edit',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      color: Colors.teal,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Duplicate',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_rounded,
                                      color: Colors.purple,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'View',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Delete',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Metrics
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactCardMetric(
                              signal.entryType == 'PRICE' ? 'Price' : 'Entry',
                              signal.entryType == 'PRICE'
                                  ? '${signal.entryPrice}'
                                  : DateFormat(
                                      'MM.dd',
                                    ).format(_getAdjustedEntryDateTime(signal)),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Expanded(
                            child: _buildCompactCardMetric(
                              'TP',
                              '${signal.tp}',
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactCardMetric(
                              'SL',
                              '${signal.sl}',
                              Colors.red,
                            ),
                          ),
                          if (signal.newTP != null) ...[
                            const SizedBox(width: 1),
                            Expanded(
                              child: _buildCompactCardMetric(
                                'NewTP',
                                '${signal.newTP}',
                                Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (signal.tpCondition1 != null ||
                          signal.tpCondition2 != null) ...[
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            if (signal.tpCondition1 != null)
                              Expanded(
                                child: _buildCompactCardMetric(
                                  'T1',
                                  signal.tpCondition1!,
                                  Colors.purple,
                                ),
                              ),
                            if (signal.tpCondition1 != null &&
                                signal.tpCondition2 != null)
                              const SizedBox(width: 1),
                            if (signal.tpCondition2 != null)
                              Expanded(
                                child: _buildCompactCardMetric(
                                  'T2',
                                  signal.tpCondition2!,
                                  Colors.purple,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _toggleSignalSelection(signal),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isBuy ? Colors.green : Colors.red)
                                      .withOpacity(0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected
                                  ? (isBuy ? Colors.green : Colors.red)
                                  : Colors.grey[300]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? (isBuy ? Colors.green : Colors.red)
                                    : Colors.grey[500],
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isSelected ? 'Selected' : 'Tap to Select',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? (isBuy ? Colors.green : Colors.red)
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMetricRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCardMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 6,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 0.5),
          Text(
            value,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
    Color? color,
  }) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? Colors.white : chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : chipColor,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? chipColor : Colors.grey[300]!,
          width: selected ? 0 : 1,
        ),
      ),
    );
  }

  Widget _buildModernBottomActionBar() {
    // Only show when signals are selected
    if (_selectedSignalIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedSignalIds.length} trade(s) selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedSignalIds.clear();
                    _selectedAccountIds.clear();
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSendingSignals
                  ? null
                  : () {
                      // Show account selection when user clicks Send
                      if (_selectedAccountIds.isEmpty) {
                        _showAccountSelection();
                      } else {
                        _sendSelectedSignals();
                      }
                    },
              icon: _isSendingSignals
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _selectedAccountIds.isEmpty
                          ? Icons.account_balance_wallet_rounded
                          : Icons.send_rounded,
                    ),
              label: Text(
                _isSendingSignals
                    ? 'Sending...'
                    : (_selectedAccountIds.isEmpty
                          ? 'Select Accounts & Send'
                          : 'Send to ${_selectedAccountIds.length} Account(s)'),
                style: const TextStyle(
                  fontSize: 17,
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
    );
  }

  Widget _buildTradeDateSelector() {
    final hasCustomDate = _selectedTradeDate != null;
    final displayText = hasCustomDate
        ? DateFormat('yyyy / MM / dd').format(_selectedTradeDate!)
        : 'Use saved entry dates';

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _pickTradeDate,
            icon: Icon(
              Icons.event_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: _pickTradeDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasCustomDate ? displayText : 'Use saved entry dates',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasCustomDate
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasCustomDate)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => setState(() => _selectedTradeDate = null),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ),
          ),
      ],
    );
  }

  void _showAccountSelection() {
    // Create a local copy of selected accounts for the modal
    final Set<String> tempSelectedIds = Set<String>.from(_selectedAccountIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Accounts',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ...widget.accountService.accounts.map((account) {
                  final isSelected = tempSelectedIds.contains(account.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        account.brand,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      value: isSelected,
                      onChanged: (checked) {
                        setModalState(() {
                          if (checked ?? false) {
                            tempSelectedIds.add(account.id);
                          } else {
                            tempSelectedIds.remove(account.id);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor: Color(account.colorValue),
                        child: Text(
                          account.name[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Update the main state when Done is pressed
                      setState(() {
                        _selectedAccountIds.clear();
                        _selectedAccountIds.addAll(tempSelectedIds);
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToCreateSignal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateSignalScreen(signalService: widget.signalService),
      ),
    );
  }

  Widget _buildServerTab() {
    int selectedPort = widget.serverManager.port;
    String selectedConnectionType = widget.serverManager.connectionType;
    final portController = TextEditingController(text: selectedPort.toString());
    final apiKeyController = TextEditingController();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.dns_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Manager',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Local Server Control',
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
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.serverManager.isRunning
                              ? [
                                  const Color(0xFF10b981),
                                  const Color(0xFF059669),
                                ]
                              : [
                                  const Color(0xFFef4444),
                                  const Color(0xFFdc2626),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (widget.serverManager.isRunning
                                        ? Colors.green
                                        : Colors.red)
                                    .withOpacity(0.3),
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
                            child: Icon(
                              widget.serverManager.isRunning
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.serverManager.isRunning
                                      ? 'Server Running'
                                      : 'Server Stopped',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (widget.serverManager.isRunning) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Port: ${widget.serverManager.port} • ${widget.serverManager.connectionType}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Port Input
                    _buildModernInputCard(
                      icon: Icons.numbers_rounded,
                      label: 'Port',
                      child: TextField(
                        controller: portController,
                        decoration: InputDecoration(
                          hintText: '8080',
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
                        keyboardType: TextInputType.number,
                        enabled: !widget.serverManager.isRunning,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Connection Type
                    _buildModernInputCard(
                      icon: Icons.settings_ethernet_rounded,
                      label: 'Connection Type',
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedConnectionType,
                        decoration: InputDecoration(
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
                            child: Text('REST API'),
                          ),
                          DropdownMenuItem(
                            value: 'WebSocket',
                            child: Text('WebSocket'),
                          ),
                          DropdownMenuItem(
                            value: 'TCP',
                            child: Text('TCP Socket'),
                          ),
                        ],
                        onChanged: widget.serverManager.isRunning
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(
                                    () => selectedConnectionType = value,
                                  );
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
                        controller: apiKeyController,
                        decoration: InputDecoration(
                          hintText: 'Leave empty for no authentication',
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
                        enabled: !widget.serverManager.isRunning,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Start/Stop Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (widget.serverManager.isRunning) {
                            await widget.serverManager.stopServer();
                          } else {
                            try {
                              final port =
                                  int.tryParse(portController.text) ?? 8080;
                              if (port < 1024 || port > 65535) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Port must be between 1024 and 65535',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              await widget.serverManager.startServer(
                                port: port,
                                connectionType: selectedConnectionType,
                                apiKey: apiKeyController.text.isEmpty
                                    ? null
                                    : apiKeyController.text,
                              );

                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              final isWorking = await widget.serverManager
                                  .testLocalConnection();

                              if (mounted) {
                                if (isWorking) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Server started and responding!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '⚠️ Server started but not responding. Check console for errors.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '❌ Failed to start server: $e',
                                    ),
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
                        icon: Icon(
                          widget.serverManager.isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          widget.serverManager.isRunning
                              ? 'Stop Server'
                              : 'Start Server',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.serverManager.isRunning
                              ? Colors.red
                              : Colors.green,
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
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return const SettingsScreen();
  }

  Widget _buildAccountsTab() {
    return AccountsScreen(accountService: widget.accountService);
  }
}
