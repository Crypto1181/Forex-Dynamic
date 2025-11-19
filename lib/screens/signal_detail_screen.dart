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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Signal Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                _buildAnimatedCard(
                  delay: 0.0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBuy
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isBuy ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              widget.signal.direction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
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
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: ${widget.signal.tradeId ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Trade Details
                _buildAnimatedCard(
                  delay: 0.1,
                  child: _buildSection(
                    'Trade Details',
                    Icons.trending_up,
                    [
                      _buildDetailRow('Direction', widget.signal.direction,
                          isBuy ? Colors.green : Colors.red),
                      _buildDetailRow('Entry Price',
                          widget.signal.entryPrice == 0
                              ? 'Market Price'
                              : widget.signal.entryPrice.toStringAsFixed(5),
                          Colors.blue),
                      _buildDetailRow('Entry Time', widget.signal.entryTime,
                          Colors.grey),
                      _buildDetailRow('Lot Size', widget.signal.lot.toString(),
                          Colors.orange),
                      _buildDetailRow('Take Profit', '${widget.signal.tp} pips',
                          Colors.green),
                      _buildDetailRow('Stop Loss', '${widget.signal.sl} pips',
                          Colors.red),
                      if (widget.signal.newTP != null)
                        _buildDetailRow('New TP',
                            '${widget.signal.newTP} pips', Colors.blue),
                    ],
                  ),
                ),

                // Conditions
                if (widget.signal.tpCondition1 != null ||
                    widget.signal.tpCondition2 != null)
                  _buildAnimatedCard(
                    delay: 0.2,
                    child: _buildSection(
                      'Time Conditions',
                      Icons.schedule,
                      [
                        if (widget.signal.tpCondition1 != null)
                          _buildDetailRow('TP Condition 1',
                              widget.signal.tpCondition1!, Colors.purple),
                        if (widget.signal.tpCondition2 != null)
                          _buildDetailRow('TP Condition 2',
                              widget.signal.tpCondition2!, Colors.purple),
                      ],
                    ),
                  ),

                // Daily Trade Info
                if (widget.signal.isDaily)
                  _buildAnimatedCard(
                    delay: 0.3,
                    child: _buildSection(
                      'Daily Trade Information',
                      Icons.repeat,
                      [
                        _buildDetailRow('Is Daily Trade', 'Yes', Colors.teal),
                        if (widget.signal.dailyTP != null)
                          _buildDetailRow('Daily TP',
                              '${widget.signal.dailyTP} pips', Colors.green),
                        if (widget.signal.dailyLot != null)
                          _buildDetailRow('Daily Lot',
                              widget.signal.dailyLot.toString(), Colors.orange),
                      ],
                    ),
                  ),

                // Account Information
                _buildAnimatedCard(
                  delay: 0.4,
                  child: _buildSection(
                    'Account Information',
                    Icons.account_balance_wallet,
                    [
                      _buildDetailRow('Account Name', widget.signal.accountName,
                          Colors.blue),
                      _buildDetailRow('Brand', widget.signal.brand, Colors.indigo),
                    ],
                  ),
                ),

                // Metadata
                _buildAnimatedCard(
                  delay: 0.5,
                  child: _buildSection(
                    'Metadata',
                    Icons.info_outline,
                    [
                      _buildDetailRow(
                        'Received At',
                        DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(widget.signal.receivedAt),
                        Colors.grey,
                      ),
                    ],
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
      duration: Duration(milliseconds: 400 + (delay * 200).toInt()),
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
      child: child,
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: valueColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
