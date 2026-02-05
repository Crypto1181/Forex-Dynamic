import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/forex_account.dart';
import '../services/account_service.dart';

class AccountsScreen extends StatefulWidget {
  final AccountService accountService;

  const AccountsScreen({
    super.key,
    required this.accountService,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Forex Accounts',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage trading accounts',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: () => _showAddAccountDialog(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Accounts List
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFf8fafc),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: StreamBuilder<List<ForexAccount>>(
                  stream: widget.accountService.accountsStream,
                  initialData: widget.accountService.accounts,
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    if (accounts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF667eea).withOpacity(0.1),
                                    const Color(0xFF764ba2).withOpacity(0.05),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.account_balance_outlined,
                                size: 80,
                                color: const Color(0xFF667eea),
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'No Accounts Yet',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0f172a),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first trading account',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: accounts.length,
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
                          child: _buildModernAccountCard(accounts[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAccountCard(ForexAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(account.colorValue),
                        Color(account.colorValue).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(account.colorValue).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      account.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
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
                        account.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0f172a),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          account.brand,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Broker Time Offset',
              value: account.brokerTimeOffset,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.inventory_2_rounded,
              label: 'Default Lot Size',
              value: account.defaultLotSize.toString(),
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.repeat_rounded,
              label: 'Default Daily Lot',
              value: account.defaultDailyLot.toString(),
              color: Colors.teal,
            ),
            if (account.comment != null && account.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.note_rounded,
                label: 'Comment',
                value: account.comment!,
                color: Colors.grey,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditAccountDialog(account),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmDialog(account),
                    icon: const Icon(Icons.delete_rounded, size: 20),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddAccountDialog() {
    _showAccountDialog();
  }

  void _showEditAccountDialog(ForexAccount account) {
    _showAccountDialog(account: account);
  }

  void _showAccountDialog({ForexAccount? account}) {
    final nameController = TextEditingController(text: account?.name ?? '');
    final offsetController = TextEditingController(
        text: account?.brokerTimeOffset ?? '-02:15');
    final lotController = TextEditingController(
        text: account?.defaultLotSize.toString() ?? '0.05');
    final dailyLotController = TextEditingController(
        text: account?.defaultDailyLot.toString() ?? '0.02');
    final commentController = TextEditingController(text: account?.comment ?? '');
    final brandController = TextEditingController(text: account?.brand ?? '');
    int selectedColor = account?.colorValue ?? AccountService.accountColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          account == null ? Icons.add_rounded : Icons.edit_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        account == null ? 'Add Account' : 'Edit Account',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDialogTextField(
                    controller: nameController,
                    label: 'Account Name',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: brandController,
                    label: 'Brand',
                    icon: Icons.business_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: offsetController,
                    label: 'Broker Time Offset (e.g., -02:15)',
                    icon: Icons.access_time_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: lotController,
                    label: 'Default Lot Size',
                    icon: Icons.inventory_2_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: dailyLotController,
                    label: 'Default Daily Lot',
                    icon: Icons.repeat_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: commentController,
                    label: 'Comment / Tag (Optional)',
                    icon: Icons.note_rounded,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Account Color:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AccountService.accountColors.map((color) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(color).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: selectedColor == color
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isEmpty ||
                                lotController.text.isEmpty ||
                                dailyLotController.text.isEmpty) {
                              return;
                            }
                            final newAccount = ForexAccount(
                              id: account?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              name: nameController.text,
                              brokerTimeOffset: offsetController.text,
                              defaultLotSize: double.parse(lotController.text),
                              defaultDailyLot: double.parse(dailyLotController.text),
                              comment: commentController.text.isEmpty
                                  ? null
                                  : commentController.text,
                              brand: brandController.text.isEmpty
                                  ? nameController.text.toUpperCase()
                                  : brandController.text.toUpperCase(),
                              colorValue: selectedColor,
                            );
                            if (account == null) {
                              widget.accountService.addAccount(newAccount);
                            } else {
                              widget.accountService.updateAccount(newAccount);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(account == null ? 'Add' : 'Save'),
                        ),
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

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
          : null,
    );
  }

  void _showDeleteConfirmDialog(ForexAccount account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Account'),
          ],
        ),
        content: Text('Are you sure you want to delete "${account.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.accountService.deleteAccount(account.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
