import 'package:supabase/supabase.dart';
import '../models/trade_signal.dart';
import 'supabase_initializer_server.dart'
    if (dart.library.ui) 'supabase_initializer_flutter.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://rffexsyqlwahiqiwndyd.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmZmV4c3lxbHdhaGlxaXduZHlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0NzYwMjIsImV4cCI6MjA4NTA1MjAyMn0.O13MZ76c7MjJaTXPQGiq3JgMktrGfx22ZYudUSI6Om4';
  
  static SupabaseClient? _client;
  static bool _initialized = false;

  /// Initialize Supabase client
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _client = await initializeSupabase(_supabaseUrl, _supabaseAnonKey);
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Supabase: $e');
    }
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return _client!;
  }

  /// Check if Supabase is initialized
  static bool get isInitialized => _initialized;

  /// Fetch all signals from Supabase
  static Future<List<TradeSignal>> fetchSignals() async {
    try {
      final response = await client
          .from('trade_signals')
          .select()
          .order('received_at', ascending: false);
      
      return (response as List)
          .map((json) => _mapFromDatabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch signals: $e');
    }
  }

  /// Map database fields (snake_case) to TradeSignal fields (camelCase)
  static TradeSignal _mapFromDatabase(Map<String, dynamic> dbJson) {
    // Handle received_at - it might be a string or DateTime
    String receivedAtStr;
    if (dbJson['received_at'] is DateTime) {
      receivedAtStr = (dbJson['received_at'] as DateTime).toIso8601String();
    } else {
      receivedAtStr = dbJson['received_at']?.toString() ?? DateTime.now().toIso8601String();
    }
    
    return TradeSignal.fromJson({
      'symbol': dbJson['symbol'],
      'direction': dbJson['direction'],
      'entryTime': dbJson['entry_time'],
      'entryPrice': dbJson['entry_price'] ?? 0.0,
      'tp': dbJson['tp'] ?? 0.0,
      'sl': dbJson['sl'] ?? 0.0,
      'tpCondition1': dbJson['tp_condition1'],
      'tpCondition2': dbJson['tp_condition2'],
      'newTP': dbJson['new_tp'],
      'lot': dbJson['lot'] ?? 0.0,
      'isDaily': dbJson['is_daily'] ?? false,
      'dailyTP': dbJson['daily_tp'],
      'dailyLot': dbJson['daily_lot'],
      'accountName': dbJson['account_name'] ?? '',
      'brand': dbJson['brand'] ?? '',
      'tradeId': dbJson['trade_id'],
      'receivedAt': receivedAtStr,
      'isDraft': dbJson['is_draft'] ?? false,
      'entryType': dbJson['entry_type'] ?? 'TIME',
    });
  }

  /// Map TradeSignal fields (camelCase) to database fields (snake_case)
  static Map<String, dynamic> _mapToDatabase(TradeSignal signal) {
    return {
      'trade_id': signal.tradeId,
      'symbol': signal.symbol,
      'direction': signal.direction,
      'entry_time': signal.entryTime,
      'entry_price': signal.entryPrice,
      'tp': signal.tp,
      'sl': signal.sl,
      'tp_condition1': signal.tpCondition1,
      'tp_condition2': signal.tpCondition2,
      'new_tp': signal.newTP,
      'lot': signal.lot,
      'is_daily': signal.isDaily,
      'daily_tp': signal.dailyTP,
      'daily_lot': signal.dailyLot,
      'account_name': signal.accountName,
      'brand': signal.brand,
      'received_at': signal.receivedAt.toIso8601String(),
      'is_draft': signal.isDraft,
      'entry_type': signal.entryType,
    };
  }

  /// Save a signal to Supabase
  static Future<void> saveSignal(TradeSignal signal) async {
    try {
      final dbJson = _mapToDatabase(signal);
      await client.from('trade_signals').upsert(
        dbJson,
        onConflict: 'trade_id',
      );
    } catch (e) {
      throw Exception('Failed to save signal: $e');
    }
  }

  /// Delete a signal from Supabase
  static Future<void> deleteSignal(String tradeId) async {
    try {
      await client
          .from('trade_signals')
          .delete()
          .eq('trade_id', tradeId);
    } catch (e) {
      throw Exception('Failed to delete signal: $e');
    }
  }

  /// Update a signal in Supabase
  static Future<void> updateSignal(TradeSignal signal) async {
    try {
      final dbJson = _mapToDatabase(signal);
      await client
          .from('trade_signals')
          .update(dbJson)
          .eq('trade_id', signal.tradeId!);
    } catch (e) {
      throw Exception('Failed to update signal: $e');
    }
  }

  /// Clear all signals from Supabase
  static Future<void> clearAllSignals() async {
    try {
      await client.from('trade_signals').delete().neq('trade_id', '');
    } catch (e) {
      throw Exception('Failed to clear signals: $e');
    }
  }
}
