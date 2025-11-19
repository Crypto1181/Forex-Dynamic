import 'dart:async';
import '../models/trade_signal.dart';
import '../models/api_response.dart';
import 'package:uuid/uuid.dart';

class SignalService {
  final List<TradeSignal> _signals = [];
  final StreamController<TradeSignal> _signalController = StreamController<TradeSignal>.broadcast();
  final Uuid _uuid = const Uuid();

  // Stream to listen for new signals
  Stream<TradeSignal> get signalStream => _signalController.stream;

  // Get all signals
  List<TradeSignal> get signals => List.unmodifiable(_signals);

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

      return ApiResponse.success(tradeId: tradeId);
    } catch (e) {
      return ApiResponse.error('Failed to process signal: ${e.toString()}', code: 'PROCESSING_ERROR');
    }
  }

  // Clear all signals
  void clearSignals() {
    _signals.clear();
  }

  // Dispose resources
  void dispose() {
    _signalController.close();
  }
}

