import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';
import '../services/signal_service.dart';

class CreateSignalScreen extends StatefulWidget {
  final SignalService signalService;
  final TradeSignal? existingSignal;

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
  String _entryType = 'TIME';
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

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
      _entryType = signal.entryType ?? 'TIME';
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
        entryType: _entryType,
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

      if (widget.existingSignal?.tradeId != null) {
        await widget.signalService.updateSignal(
          widget.existingSignal!.tradeId!,
          draft,
        );
      } else {
        widget.signalService.addDraftSignal(draft);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  widget.existingSignal != null
                      ? 'Signal updated successfully'
                      : 'Signal saved successfully',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Failed to save signal: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      extendBodyBehindAppBar: true,
      body: Container(
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_chart_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingSignal != null
                                ? 'Edit Signal'
                                : 'Create Signal',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Configure trade parameters',
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

              // Form Content
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
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Entry Type Toggle
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Entry Type',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _entryType = 'TIME',
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _entryType == 'TIME'
                                                    ? Colors.white
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: _entryType == 'TIME'
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.1),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ]
                                                    : [],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Time Entry',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _entryType == 'TIME'
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _entryType = 'PRICE',
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _entryType == 'PRICE'
                                                    ? Colors.white
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: _entryType == 'PRICE'
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.1),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ]
                                                    : [],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Price Entry',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _entryType == 'PRICE'
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Symbol & Direction Row
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.currency_exchange_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Symbol & Direction',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildModernTextField(
                                          controller: _symbolController,
                                          label: 'Symbol',
                                          icon: Icons.currency_bitcoin_rounded,
                                          validator: (v) => v?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _direction,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              labelText: 'Direction',
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 12,
                                                  ),
                                              isDense: true,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            selectedItemBuilder:
                                                (BuildContext context) {
                                                  return ['BUY', 'SELL'].map((
                                                    String value,
                                                  ) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 4,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            value == 'BUY'
                                                                ? Icons
                                                                      .trending_up_rounded
                                                                : Icons
                                                                      .trending_down_rounded,
                                                            color:
                                                                value == 'BUY'
                                                                ? Colors.blue
                                                                : Colors.red,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              value,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                            items: [
                                              DropdownMenuItem(
                                                value: 'BUY',
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.trending_up_rounded,
                                                      color: Colors.blue,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'BUY',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'SELL',
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .trending_down_rounded,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'SELL',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) =>
                                                setState(() => _direction = v!),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Entry Price & Lot
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.price_check_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _entryType == 'PRICE'
                                            ? 'Main Entry Details'
                                            : 'Entry Details',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _entryPriceController,
                                          label: _entryType == 'PRICE'
                                              ? 'Main Entry Price'
                                              : 'Entry Price',
                                          icon: Icons.attach_money_rounded,
                                          keyboardType: TextInputType.number,
                                          validator: (v) {
                                            if (_entryType == 'PRICE' &&
                                                (v?.isEmpty ?? true)) {
                                              return 'Required for Price Entry';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _lotController,
                                          label: 'Lot Size',
                                          icon: Icons.inventory_2_rounded,
                                          keyboardType: TextInputType.number,
                                          validator: (v) => v?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Entry Date & Time (Or Daily Time for Price Entry)
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _entryType == 'PRICE'
                                            ? 'Daily Trade Time'
                                            : 'Entry Time',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      if (_entryType == 'TIME') ...[
                                        Expanded(
                                          child: _buildDateTimePicker(
                                            icon: Icons.event_rounded,
                                            label: 'Date',
                                            value: DateFormat(
                                              'yyyy.MM.dd',
                                            ).format(_entryDate),
                                            onTap: _selectDate,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: _buildDateTimePicker(
                                          icon: Icons.access_time_rounded,
                                          label: 'Time',
                                          value: DateFormat(
                                            'HH:mm',
                                          ).format(_entryDate),
                                          onTap: _selectTime,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_entryType == 'PRICE') ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'This time will be used for daily fixed-time trades.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // TP & SL
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Take Profit & Stop Loss',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _tpController,
                                          label: 'TP (pips)',
                                          icon: Icons.trending_up_rounded,
                                          keyboardType: TextInputType.number,
                                          validator: (v) => v?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _slController,
                                          label: 'SL (pips)',
                                          icon: Icons.trending_down_rounded,
                                          keyboardType: TextInputType.number,
                                          validator: (v) => v?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // TP Conditions
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'TP Conditions (Optional)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _tpCondition1Controller,
                                          label: 'TP Time 1',
                                          hintText: 'HH:mm',
                                          icon: Icons.schedule_rounded,
                                          color: Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _tpCondition2Controller,
                                          label: 'TP Time 2',
                                          hintText: 'HH:mm',
                                          icon: Icons.schedule_rounded,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    controller: _newTPController,
                                    label: 'New TP (pips)',
                                    icon: Icons.edit_rounded,
                                    keyboardType: TextInputType.number,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Daily Trade Toggle
                            _buildModernCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Daily Trade',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _isDaily
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1)
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _isDaily
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.grey[300]!,
                                        width: _isDaily ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Enable daily re-entry trades',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: _isDaily
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isDaily,
                                          onChanged: (value) =>
                                              setState(() => _isDaily = value),
                                          activeThumbColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isDaily) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildModernTextField(
                                            controller: _dailyTPController,
                                            label: 'Daily TP',
                                            icon: Icons.trending_up_rounded,
                                            keyboardType: TextInputType.number,
                                            color: Colors.teal,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildModernTextField(
                                            controller: _dailyLotController,
                                            label: 'Daily Lot',
                                            icon: Icons.inventory_2_rounded,
                                            keyboardType: TextInputType.number,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Save Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF667eea),
                                    const Color(0xFF764ba2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667eea,
                                    ).withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveSignal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.save_rounded,
                                            size: 26,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            widget.existingSignal != null
                                                ? 'Update Signal'
                                                : 'Save Signal',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Color? color,
  }) {
    final fieldColor = color ?? Theme.of(context).colorScheme.primary;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null
            ? Icon(icon, color: fieldColor, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: fieldColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
          : null,
      validator: validator,
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0f172a),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Colors.grey[600],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
