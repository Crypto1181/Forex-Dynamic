import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';
import '../services/signal_service.dart';

class CreateSignalScreen extends StatefulWidget {
  final SignalService signalService;
  final TradeSignal? existingSignal; // For editing

  const CreateSignalScreen({
    super.key,
    required this.signalService,
    this.existingSignal,
  });

  @override
  State<CreateSignalScreen> createState() => _CreateSignalScreenState();
}

class _CreateSignalScreenState extends State<CreateSignalScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController(text: 'AUDUSD');
  final _entryPriceController = TextEditingController(text: '0');
  final _tpController = TextEditingController(text: '19');
  final _slController = TextEditingController(text: '0');
  final _tpCondition1Controller = TextEditingController(text: '22:25');
  final _tpCondition2Controller = TextEditingController(text: '13:23');
  final _newTPController = TextEditingController(text: '9');
  final _lotController = TextEditingController(text: '0.03');
  final _dailyTPController = TextEditingController(text: '20');
  final _dailyLotController = TextEditingController(text: '0.02');

  String _direction = 'BUY';
  DateTime _entryDate = DateTime.now();
  bool _isDaily = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
    
    // Populate fields if editing
    if (widget.existingSignal != null) {
      final signal = widget.existingSignal!;
      _symbolController.text = signal.symbol;
      _direction = signal.direction;
      _entryPriceController.text = signal.entryPrice.toString();
      _tpController.text = signal.tp.toString();
      _slController.text = signal.sl.toString();
      _tpCondition1Controller.text = signal.tpCondition1 ?? '';
      _tpCondition2Controller.text = signal.tpCondition2 ?? '';
      _newTPController.text = signal.newTP?.toString() ?? '';
      _lotController.text = signal.lot.toString();
      _isDaily = signal.isDaily;
      _dailyTPController.text = signal.dailyTP?.toString() ?? '';
      _dailyLotController.text = signal.dailyLot?.toString() ?? '';
      try {
        _entryDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(signal.entryTime);
      } catch (_) {
        _entryDate = signal.receivedAt;
      }
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _symbolController.dispose();
    _entryPriceController.dispose();
    _tpController.dispose();
    _slController.dispose();
    _tpCondition1Controller.dispose();
    _tpCondition2Controller.dispose();
    _newTPController.dispose();
    _lotController.dispose();
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
        _entryDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _entryDate.hour,
          _entryDate.minute,
        );
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

  Future<void> _saveSignal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final draft = TradeSignal(
        symbol: _symbolController.text.toUpperCase(),
        direction: _direction,
        entryTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(_entryDate),
        entryPrice: double.tryParse(_entryPriceController.text) ?? 0.0,
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
        accountName: 'Draft',
        brand: 'Forex Dynamic',
        isDraft: true,
      );

      // Update existing signal or create new one
      if (widget.existingSignal?.tradeId != null) {
        await widget.signalService.updateSignal(widget.existingSignal!.tradeId!, draft);
      } else {
        widget.signalService.addDraftSignal(draft);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingSignal != null 
                ? 'Signal updated successfully' 
                : 'Signal saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save signal: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.existingSignal != null ? 'Edit Trade Signal' : 'Create Trade Signal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card
                _buildAnimatedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.existingSignal != null ? 'Edit Trade Signal' : 'Create Trade Signal',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Symbol
                _buildAnimatedCard(
                  delay: 0.1,
                  child: _buildTextField(
                    label: 'Symbol',
                    controller: _symbolController,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    icon: Icons.currency_exchange,
                  ),
                ),
                const SizedBox(height: 16),

                // Direction
                _buildAnimatedCard(
                  delay: 0.15,
                  child: DropdownButtonFormField<String>(
                    value: _direction,
                    decoration: InputDecoration(
                      labelText: 'Direction',
                      prefixIcon: Icon(
                        _direction == 'BUY' ? Icons.arrow_upward : Icons.arrow_downward,
                        color: _direction == 'BUY' ? Colors.green : Colors.red,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'BUY',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('BUY'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'SELL',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('SELL'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _direction = v!),
                  ),
                ),
                const SizedBox(height: 16),

                // Entry Price
                _buildAnimatedCard(
                  delay: 0.2,
                  child: _buildTextField(
                    label: 'Entry Price',
                    controller: _entryPriceController,
                    keyboardType: TextInputType.number,
                    icon: Icons.price_check,
                  ),
                ),
                const SizedBox(height: 16),

                // Entry Date & Time
                _buildAnimatedCard(
                  delay: 0.25,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Entry Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('yyyy.MM.dd').format(_entryDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Entry Time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('HH:mm').format(_entryDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // TP & SL
                _buildAnimatedCard(
                  delay: 0.3,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'TP',
                          controller: _tpController,
                          keyboardType: TextInputType.number,
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'SL',
                          controller: _slController,
                          keyboardType: TextInputType.number,
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          icon: Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // TP Conditions
                _buildAnimatedCard(
                  delay: 0.35,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'TP Condition Time 1',
                          controller: _tpCondition1Controller,
                          hintText: 'HH:mm',
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'TP Condition Time 2',
                          controller: _tpCondition2Controller,
                          hintText: 'HH:mm',
                          icon: Icons.schedule,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // New TP
                _buildAnimatedCard(
                  delay: 0.4,
                  child: _buildTextField(
                    label: 'New TP',
                    controller: _newTPController,
                    keyboardType: TextInputType.number,
                    icon: Icons.edit,
                  ),
                ),
                const SizedBox(height: 16),

                // LOT
                _buildAnimatedCard(
                  delay: 0.45,
                  child: _buildTextField(
                    label: 'LOT',
                    controller: _lotController,
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    icon: Icons.inventory,
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Toggle
                _buildAnimatedCard(
                  delay: 0.5,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Daily',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isDaily,
                          onChanged: (value) => setState(() => _isDaily = value),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        Text(
                          _isDaily ? 'Yes' : 'No',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isDaily
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isDaily) ...[
                  const SizedBox(height: 16),
                  _buildAnimatedCard(
                    delay: 0.55,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Daily TP',
                            controller: _dailyTPController,
                            keyboardType: TextInputType.number,
                            icon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Daily LOT',
                            controller: _dailyLotController,
                            keyboardType: TextInputType.number,
                            icon: Icons.inventory,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Send Button
                _buildAnimatedCard(
                  delay: 0.65,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSignal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.existingSignal != null ? 'Update Signal' : 'Save Signal',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({
    required Widget child,
    double delay = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (delay * 1000).toInt()),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
          : null,
      validator: validator,
    );
  }
}
