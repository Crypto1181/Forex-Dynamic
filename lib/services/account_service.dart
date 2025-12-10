import 'dart:async';
import 'dart:convert';
import '../models/forex_account.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountService {
  final List<ForexAccount> _accounts = [];
  final StreamController<List<ForexAccount>> _accountsController = 
      StreamController<List<ForexAccount>>.broadcast();
  final Uuid _uuid = const Uuid();
  static const String _storageKey = 'forex_accounts';

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
    _loadAccounts();
  }

  /// Load accounts from storage, or create defaults if none exist
  Future<void> _loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_storageKey);
      
      if (accountsJson != null && accountsJson.isNotEmpty) {
        // Load saved accounts
        final List<dynamic> accountsList = jsonDecode(accountsJson);
        _accounts.clear();
        for (var accountJson in accountsList) {
          _accounts.add(ForexAccount.fromJson(accountJson as Map<String, dynamic>));
        }
        _notifyListeners();
      } else {
        // No saved accounts, create defaults
        _loadDefaultAccounts();
        await _saveAccounts();
      }
    } catch (e) {
      // If loading fails, create defaults
      _loadDefaultAccounts();
      await _saveAccounts();
    }
  }

  void _loadDefaultAccounts() {
    // Add some default accounts (without saving to avoid recursion)
    _accounts.add(ForexAccount(
      id: _uuid.v4(),
      name: 'My Forex Trade',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'MY FOREX TRADE',
      colorValue: accountColors[0],
    ));
    
    _accounts.add(ForexAccount(
      id: _uuid.v4(),
      name: 'Funded Forex',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'FUNDED FOREX',
      colorValue: accountColors[1],
    ));
    
    _accounts.add(ForexAccount(
      id: _uuid.v4(),
      name: 'Demo Forex',
      brokerTimeOffset: '-02:15',
      defaultLotSize: 0.05,
      brand: 'DEMO FOREX',
      colorValue: accountColors[2],
    ));
    _notifyListeners();
  }

  /// Save accounts to persistent storage
  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = jsonEncode(
        _accounts.map((account) => account.toJson()).toList(),
      );
      await prefs.setString(_storageKey, accountsJson);
    } catch (e) {
      // Ignore storage errors
    }
  }

  void addAccount(ForexAccount account) {
    _accounts.add(account);
    _notifyListeners();
    _saveAccounts(); // Fire and forget - async save
  }

  void updateAccount(ForexAccount account) {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      _notifyListeners();
      _saveAccounts(); // Fire and forget - async save
    }
  }

  void deleteAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    _notifyListeners();
    _saveAccounts(); // Fire and forget - async save
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

