import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trade_signal.dart';

class SignalDetailScreen extends StatelessWidget {
  final TradeSignal signal;

  const SignalDetailScreen({
    super.key,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signal: ${signal.symbol}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              color: signal.direction == 'BUY' ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: signal.direction == 'BUY'
                          ? Colors.green
                          : Colors.red,
                      child: Text(
                        signal.direction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Trade ID: ${signal.tradeId ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Trade Details
            _buildSection(
              'Trade Details',
              [
                _buildDetailRow('Direction', signal.direction),
                _buildDetailRow('Entry Time', signal.entryTime),
                _buildDetailRow('Lot Size', signal.lot.toString()),
                _buildDetailRow('Take Profit', '${signal.tp} pips'),
                _buildDetailRow('Stop Loss', '${signal.sl} pips'),
                if (signal.newTP != null)
                  _buildDetailRow('New TP', '${signal.newTP} pips'),
              ],
            ),
            // Conditions
            if (signal.tpCondition1 != null || signal.tpCondition2 != null)
              _buildSection(
                'Time Conditions',
                [
                  if (signal.tpCondition1 != null)
                    _buildDetailRow('TP Condition 1', signal.tpCondition1!),
                  if (signal.tpCondition2 != null)
                    _buildDetailRow('TP Condition 2', signal.tpCondition2!),
                ],
              ),
            // Daily Trade Info
            if (signal.isDaily)
              _buildSection(
                'Daily Trade Information',
                [
                  _buildDetailRow('Is Daily Trade', 'Yes'),
                  if (signal.dailyTP != null)
                    _buildDetailRow('Daily TP', '${signal.dailyTP} pips'),
                  if (signal.dailyLot != null)
                    _buildDetailRow('Daily Lot', signal.dailyLot.toString()),
                ],
              ),
            // Account Information
            _buildSection(
              'Account Information',
              [
                _buildDetailRow('Account Name', signal.accountName),
                _buildDetailRow('Brand', signal.brand),
              ],
            ),
            // Metadata
            _buildSection(
              'Metadata',
              [
                _buildDetailRow(
                  'Received At',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(signal.receivedAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

