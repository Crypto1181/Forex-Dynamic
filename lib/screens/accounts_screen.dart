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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Accounts'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<ForexAccount>>(
        stream: widget.accountService.accountsStream,
        initialData: widget.accountService.accounts,
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return const Center(
              child: Text('No accounts yet. Add one to get started.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              return _buildAccountCard(accounts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(ForexAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(account.colorValue),
                  child: Text(
                    account.name[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Broker Time Offset', account.brokerTimeOffset),
            const SizedBox(height: 8),
            _buildInfoRow('Default Lot Size', account.defaultLotSize.toString()),
            if (account.comment != null && account.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Comment / Tag', account.comment!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditAccountDialog(account),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmDialog(account),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
    final commentController = TextEditingController(text: account?.comment ?? '');
    final brandController = TextEditingController(text: account?.brand ?? '');
    int selectedColor = account?.colorValue ?? AccountService.accountColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(account == null ? 'Add Account' : 'Edit Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: offsetController,
                  decoration: const InputDecoration(
                    labelText: 'Broker Time Offset (e.g., -02:15)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lotController,
                  decoration: const InputDecoration(
                    labelText: 'Default Lot Size',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comment / Tag',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Color:'),
                Wrap(
                  spacing: 8,
                  children: AccountService.accountColors.map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    lotController.text.isEmpty) {
                  return;
                }
                final newAccount = ForexAccount(
                  id: account?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  brokerTimeOffset: offsetController.text,
                  defaultLotSize: double.parse(lotController.text),
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
              child: Text(account == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(ForexAccount account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

