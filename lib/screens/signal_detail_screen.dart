import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';

class SignalDetailScreen extends StatefulWidget {
  final TradeSignal signal;

  const SignalDetailScreen({
    super.key,
    required this.signal,
  });

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen>
    with SingleTickerProviderStateMixin {
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.signal.direction == 'BUY';
    final gradientColors = isBuy
        ? [const Color(0xFF10b981), const Color(0xFF3b82f6)]
        : [const Color(0xFFef4444), const Color(0xFFf97316)];
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                      child: Icon(
                        isBuy ? Icons.trending_up_rounded : Icons.trending_down_rounded,
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
                            widget.signal.symbol,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.signal.direction,
                              style: TextStyle(
                                fontSize: 14,
                                color: isBuy ? const Color(0xFF10b981) : const Color(0xFFef4444),
                                fontWeight: FontWeight.bold,
                              ),
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Trade Details Card
                            _buildModernSectionCard(
                              icon: Icons.analytics_rounded,
                              iconColor: Colors.blue,
                              title: 'Trade Details',
                              children: [
                                _buildDetailRow(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Direction',
                                  value: widget.signal.direction,
                                  valueColor: isBuy ? Colors.green : Colors.red,
                                ),
                                _buildDetailRow(
                                  icon: Icons.attach_money_rounded,
                                  label: 'Entry Price',
                                  value: widget.signal.entryPrice == 0
                                      ? 'Market Price'
                                      : widget.signal.entryPrice.toStringAsFixed(5),
                                  valueColor: Colors.blue,
                                ),
                                _buildDetailRow(
                                  icon: Icons.access_time_rounded,
                                  label: 'Entry Time',
                                  value: widget.signal.entryTime,
                                  valueColor: Colors.grey,
                                ),
                                _buildDetailRow(
                                  icon: Icons.inventory_2_rounded,
                                  label: 'Lot Size',
                                  value: widget.signal.lot.toString(),
                                  valueColor: Colors.orange,
                                ),
                                _buildDetailRow(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Take Profit',
                                  value: '${widget.signal.tp} pips',
                                  valueColor: Colors.green,
                                ),
                                _buildDetailRow(
                                  icon: Icons.trending_down_rounded,
                                  label: 'Stop Loss',
                                  value: '${widget.signal.sl} pips',
                                  valueColor: Colors.red,
                                ),
                                if (widget.signal.newTP != null)
                                  _buildDetailRow(
                                    icon: Icons.edit_rounded,
                                    label: 'New TP',
                                    value: '${widget.signal.newTP} pips',
                                    valueColor: Colors.blue,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Time Conditions
                            if (widget.signal.tpCondition1 != null ||
                                widget.signal.tpCondition2 != null)
                              _buildModernSectionCard(
                                icon: Icons.schedule_rounded,
                                iconColor: Colors.purple,
                                title: 'Time Conditions',
                                children: [
                                  if (widget.signal.tpCondition1 != null)
                                    _buildDetailRow(
                                      icon: Icons.schedule_rounded,
                                      label: 'TP Condition 1',
                                      value: widget.signal.tpCondition1!,
                                      valueColor: Colors.purple,
                                    ),
                                  if (widget.signal.tpCondition2 != null)
                                    _buildDetailRow(
                                      icon: Icons.schedule_rounded,
                                      label: 'TP Condition 2',
                                      value: widget.signal.tpCondition2!,
                                      valueColor: Colors.purple,
                                    ),
                                ],
                              ),
                            if (widget.signal.tpCondition1 != null ||
                                widget.signal.tpCondition2 != null)
                              const SizedBox(height: 16),

                            // Daily Trade Info
                            if (widget.signal.isDaily)
                              _buildModernSectionCard(
                                icon: Icons.repeat_rounded,
                                iconColor: Colors.teal,
                                title: 'Daily Trade Information',
                                children: [
                                  _buildDetailRow(
                                    icon: Icons.repeat_rounded,
                                    label: 'Is Daily Trade',
                                    value: 'Yes',
                                    valueColor: Colors.teal,
                                  ),
                                  if (widget.signal.dailyTP != null)
                                    _buildDetailRow(
                                      icon: Icons.trending_up_rounded,
                                      label: 'Daily TP',
                                      value: '${widget.signal.dailyTP} pips',
                                      valueColor: Colors.green,
                                    ),
                                  if (widget.signal.dailyLot != null)
                                    _buildDetailRow(
                                      icon: Icons.inventory_2_rounded,
                                      label: 'Daily Lot',
                                      value: widget.signal.dailyLot.toString(),
                                      valueColor: Colors.orange,
                                    ),
                                ],
                              ),
                            if (widget.signal.isDaily) const SizedBox(height: 16),

                            // Account Information
                            _buildModernSectionCard(
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: Colors.indigo,
                              title: 'Account Information',
                              children: [
                                _buildDetailRow(
                                  icon: Icons.person_rounded,
                                  label: 'Account Name',
                                  value: widget.signal.accountName,
                                  valueColor: Colors.blue,
                                ),
                                _buildDetailRow(
                                  icon: Icons.business_rounded,
                                  label: 'Brand',
                                  value: widget.signal.brand,
                                  valueColor: Colors.indigo,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Metadata
                            _buildModernSectionCard(
                              icon: Icons.info_outline_rounded,
                              iconColor: Colors.grey,
                              title: 'Metadata',
                              children: [
                                _buildDetailRow(
                                  icon: Icons.access_time_rounded,
                                  label: 'Received At',
                                  value: DateFormat('yyyy-MM-dd HH:mm:ss')
                                      .format(widget.signal.receivedAt),
                                  valueColor: Colors.grey,
                                ),
                              ],
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

  Widget _buildModernSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0f172a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: valueColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: valueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
