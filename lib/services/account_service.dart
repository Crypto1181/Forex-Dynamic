import 'dart:async';
import '../models/forex_account.dart';
import 'package:uuid/uuid.dart';

class AccountService {
  final List<ForexAccount> _accounts = [];
  final StreamController<List<ForexAccount>> _accountsController = 
      StreamController<List<ForexAccount>>.broadcast();
  final Uuid _uuid = const Uuid();

  // Predefined color values for accounts
  static const List<int> accountColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFF44336, // Red
    0xFF00BCD4, // Cyan
  ];

  Stream<List<ForexAccount>> get accountsStream => _accountsController.stream;
  List<ForexAccount> get accounts => List.unmodifiable(_accounts);

  AccountService() {
    _loadDefaultAccounts();
  }

  void _loadDefaultAccounts() {
    // Add some default accounts
    addAccount(ForexAccount(
      id: _uuid.v4(),
      name: 'My Forex Trade',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'MY FOREX TRADE',
      colorValue: accountColors[0],
    ));
    
    addAccount(ForexAccount(
      id: _uuid.v4(),
      name: 'Funded Forex',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'FUNDED FOREX',
      colorValue: accountColors[1],
    ));
    
    addAccount(ForexAccount(
      id: _uuid.v4(),
      name: 'Demo Forex',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'DEMO FOREX',
      colorValue: accountColors[2],
    ));
  }

  void addAccount(ForexAccount account) {
    _accounts.add(account);
    _notifyListeners();
  }

  void updateAccount(ForexAccount account) {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      _notifyListeners();
    }
  }

  void deleteAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    _notifyListeners();
  }

  ForexAccount? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  void _notifyListeners() {
    _accountsController.add(List.unmodifiable(_accounts));
  }

  void dispose() {
    _accountsController.close();
  }
}

