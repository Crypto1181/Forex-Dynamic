import 'dart:async';
import 'dart:convert';
import '../models/trade_signal.dart';
import '../models/api_response.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignalService {
  final List<TradeSignal> _signals = [];
  final StreamController<TradeSignal> _signalController = StreamController<TradeSignal>.broadcast();
  final Uuid _uuid = const Uuid();
  static const String _signalsKey = 'saved_trade_signals';

  // Stream to listen for new signals
  Stream<TradeSignal> get signalStream => _signalController.stream;

  // Get all signals
  List<TradeSignal> get signals => List.unmodifiable(_signals);

  // Initialize and load saved signals
  Future<void> initialize() async {
    await loadSignals();
  }

  // Load signals from storage
  Future<void> loadSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signalsJson = prefs.getString(_signalsKey);
      if (signalsJson != null) {
        final List<dynamic> decoded = json.decode(signalsJson);
        _signals.clear();
        _signals.addAll(
          decoded.map((json) => TradeSignal.fromJson(json as Map<String, dynamic>))
        );
        // Sort by receivedAt descending (newest first)
        _signals.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      }
    } catch (e) {
      // If loading fails, start with empty list
      _signals.clear();
    }
  }

  // Save signals to storage
  Future<void> _saveSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signalsJson = json.encode(
        _signals.map((signal) => signal.toJson()).toList()
      );
      await prefs.setString(_signalsKey, signalsJson);
    } catch (e) {
      // Silently fail - data will be lost but app won't crash
    }
  }

  TradeSignal? getSignalById(String id) {
    try {
      return _signals.firstWhere((signal) => signal.tradeId == id);
    } catch (_) {
      return null;
    }
  }

  TradeSignal addDraftSignal(TradeSignal signal) {
    final tradeId = signal.tradeId ?? _uuid.v4();
    final draft = signal.copyWith(
      tradeId: tradeId,
      isDraft: true,
      receivedAt: DateTime.now(),
    );
    _signals.insert(0, draft);
    _signalController.add(draft);
    _saveSignals(); // Save to storage
    return draft;
  }

  // Process a trade signal
  ApiResponse processSignal(Map<String, dynamic> jsonData) {
    try {
      // Parse the trade signal
      final signal = TradeSignal.fromJson(jsonData);
      
      // Validate the signal
      final validationError = signal.validate();
      if (validationError != null) {
        return ApiResponse.error(validationError, code: 'VALIDATION_ERROR');
      }

      // Generate a unique trade ID
      final tradeId = _uuid.v4();
      final signalWithId = TradeSignal(
        symbol: signal.symbol,
        direction: signal.direction,
        entryTime: signal.entryTime,
        entryPrice: signal.entryPrice,
        tp: signal.tp,
        sl: signal.sl,
        tpCondition1: signal.tpCondition1,
        tpCondition2: signal.tpCondition2,
        newTP: signal.newTP,
        lot: signal.lot,
        isDaily: signal.isDaily,
        dailyTP: signal.dailyTP,
        dailyLot: signal.dailyLot,
        accountName: signal.accountName,
        brand: signal.brand,
        tradeId: tradeId,
        receivedAt: signal.receivedAt,
        isDraft: false,
      );

      // Add to list
      _signals.insert(0, signalWithId); // Add to beginning for newest first

      // Emit to stream
      _signalController.add(signalWithId);

      // Save to storage
      _saveSignals();

      return ApiResponse.success(tradeId: tradeId);
    } catch (e) {
      return ApiResponse.error('Failed to process signal: ${e.toString()}', code: 'PROCESSING_ERROR');
    }
  }

  // Clear all signals
  Future<void> clearSignals() async {
    _signals.clear();
    await _saveSignals(); // Clear from storage too
  }

  // Dispose resources
  void dispose() {
    _signalController.close();
  }
}

