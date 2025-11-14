import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';
import '../services/account_service.dart';
import '../services/signal_service.dart';
import '../services/server_manager.dart';
import '../services/signal_client.dart';
import '../services/settings_service.dart';

class CreateSignalScreen extends StatefulWidget {
  final AccountService accountService;
  final SignalService signalService;
  final ServerManager serverManager;
  final List<String> selectedAccountIds;

  const CreateSignalScreen({
    super.key,
    required this.accountService,
    required this.signalService,
    required this.serverManager,
    this.selectedAccountIds = const [],
  });

  @override
  State<CreateSignalScreen> createState() => _CreateSignalScreenState();
}

class _CreateSignalScreenState extends State<CreateSignalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController(text: 'AUDUSD');
  final _tpController = TextEditingController(text: '28');
  final _slController = TextEditingController(text: '0');
  final _tpCondition1Controller = TextEditingController(text: '21:10');
  final _tpCondition2Controller = TextEditingController(text: '09:40');
  final _newTPController = TextEditingController(text: '14');
  final _lotController = TextEditingController(text: '0.2');
  final _trailingController = TextEditingController(text: '0');
  final _trailingTPController = TextEditingController(text: '0.01');
  final _dailyTPController = TextEditingController(text: '20');
  final _dailyLotController = TextEditingController(text: '0.01');

  String _direction = 'SELL';
  DateTime _entryDate = DateTime.now();
  bool _isDaily = true;
  Set<String> _selectedAccountIds = {};

  @override
  void initState() {
    super.initState();
    _selectedAccountIds = Set.from(widget.selectedAccountIds);
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _tpController.dispose();
    _slController.dispose();
    _tpCondition1Controller.dispose();
    _tpCondition2Controller.dispose();
    _newTPController.dispose();
    _lotController.dispose();
    _trailingController.dispose();
    _trailingTPController.dispose();
    _dailyTPController.dispose();
    _dailyLotController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _entryDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryDate),
    );
    if (picked != null) {
      setState(() {
        _entryDate = DateTime(
          _entryDate.year,
          _entryDate.month,
          _entryDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _sendSignals() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one account')),
      );
      return;
    }

    final settingsService = SettingsService();
    final remoteServerUrl = await settingsService.getRemoteServerUrl();

    // Determine which server to use
    String host;
    int port;
    String connectionType;

    if (remoteServerUrl != null && remoteServerUrl.isNotEmpty) {
      // Use remote server
      final parsed = settingsService.parseServerUrl(remoteServerUrl);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid remote server URL. Please check settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      host = parsed['host'] as String;
      port = parsed['port'] as int;
      connectionType = parsed['connectionType'] as String;
    } else {
      // Use local server (fallback)
      if (!widget.serverManager.isRunning) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No remote server configured and local server is not running.\nPlease configure remote server in Settings or start local server.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      host = 'localhost';
      port = widget.serverManager.port;
      connectionType = widget.serverManager.connectionType;
    }

    final accounts = widget.accountService.accounts
        .where((a) => _selectedAccountIds.contains(a.id))
        .toList();

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    // Create signal client
    final useHttps =
        remoteServerUrl != null &&
        (remoteServerUrl.startsWith('https://') ||
            remoteServerUrl.startsWith('wss://'));
    final client = SignalClient(
      host: host,
      port: port,
      connectionType: connectionType,
      apiKey: await settingsService.getApiKey(),
      useHttps: useHttps,
    );

    for (final account in accounts) {
      try {
        final signal = TradeSignal(
          symbol: _symbolController.text.toUpperCase(),
          direction: _direction,
          entryTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(_entryDate),
          tp: double.parse(_tpController.text),
          sl: double.parse(_slController.text),
          tpCondition1: _tpCondition1Controller.text.isEmpty
              ? null
              : _tpCondition1Controller.text,
          tpCondition2: _tpCondition2Controller.text.isEmpty
              ? null
              : _tpCondition2Controller.text,
          newTP: _newTPController.text.isEmpty
              ? null
              : double.parse(_newTPController.text),
          lot: double.parse(_lotController.text),
          isDaily: _isDaily,
          dailyTP: _isDaily && _dailyTPController.text.isNotEmpty
              ? double.parse(_dailyTPController.text)
              : null,
          dailyLot: _isDaily && _dailyLotController.text.isNotEmpty
              ? double.parse(_dailyLotController.text)
              : null,
          accountName: account.name,
          brand: account.brand,
        );

        // Send signal to server (EA will receive it)
        final response = await client.sendSignal(signal);

        if (response.status == 'success') {
          // Also store locally for display
          widget.signalService.processSignal(signal.toJson());
          successCount++;
        } else {
          errorCount++;
          errors.add('${account.name}: ${response.message}');
        }
      } catch (e) {
        errorCount++;
        errors.add('${account.name}: ${e.toString()}');
      }
    }

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
    }

    // Show result
    if (mounted) {
      String message;
      Color backgroundColor;
      if (successCount > 0 && errorCount == 0) {
        message = 'Successfully sent $successCount signal(s) to EA';
        backgroundColor = Colors.green;
      } else if (successCount > 0 && errorCount > 0) {
        message = 'Sent $successCount signal(s), $errorCount failed';
        backgroundColor = Colors.orange;
      } else {
        message = 'Failed to send signals: ${errors.join(", ")}';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
        ),
      );

      if (successCount > 0) {
        Navigator.pop(context); // Close create signal screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trade Signal'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Symbol
            _buildTextField(
              label: 'Symbol',
              controller: _symbolController,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Direction
            DropdownButtonFormField<String>(
              value: _direction,
              decoration: const InputDecoration(
                labelText: 'Direction',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'BUY', child: Text('BUY')),
                DropdownMenuItem(value: 'SELL', child: Text('SELL')),
              ],
              onChanged: (v) => setState(() => _direction = v!),
            ),
            const SizedBox(height: 16),

            // Entry Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Entry Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('yyyy.MM.dd').format(_entryDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Entry Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('HH:mm').format(_entryDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TP & SL
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'TP',
                    controller: _tpController,
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'SL',
                    controller: _slController,
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TP Conditions
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'TP Condition Time 1',
                    controller: _tpCondition1Controller,
                    hintText: 'HH:mm',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'TP Condition Time 2',
                    controller: _tpCondition2Controller,
                    hintText: 'HH:mm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // New TP
            _buildTextField(
              label: 'New TP',
              controller: _newTPController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // LOT
            _buildTextField(
              label: 'LOT',
              controller: _lotController,
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Trailing & Trailing TP
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Trailing',
                    controller: _trailingController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Trailing TP',
                    controller: _trailingTPController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daily Checkbox
            CheckboxListTile(
              title: const Text('Daily'),
              value: _isDaily,
              onChanged: (v) => setState(() => _isDaily = v ?? false),
            ),
            if (_isDaily) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Daily TP',
                      controller: _dailyTPController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Daily LOT',
                      controller: _dailyLotController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Account Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Accounts',
                      style: TextStyle(
                        fontSize: 18,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _sendSignals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Send Now',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
          : null,
      validator: validator,
    );
  }
}
