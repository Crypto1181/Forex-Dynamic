import 'dart:convert';
import '../models/trade_signal.dart';
import 'supabase_service.dart';

/// Load signals from Supabase
/// Returns JSON string of signals array (for compatibility with existing code)
Future<String?> getStoredSignals(String key) async {
  try {
    if (!SupabaseService.isInitialized) {
      await SupabaseService.initialize();
    }
    
    final signals = await SupabaseService.fetchSignals();
    if (signals.isEmpty) {
      return null;
    }
    
    // Convert to JSON string for compatibility
    return json.encode(
      signals.map((signal) => signal.toJson()).toList(),
    );
  } catch (e) {
    // If Supabase fails, return null (fallback behavior)
    print('Error loading signals from Supabase: $e');
    return null;
  }
}

/// Save signals to Supabase
/// Note: This function now saves individual signals, not a batch
Future<void> saveSignals(String key, String value) async {
  try {
    if (!SupabaseService.isInitialized) {
      await SupabaseService.initialize();
    }
    
    // Parse the JSON string to get all signals
    final List<dynamic> decoded = json.decode(value);
    
    // Save each signal to Supabase
    for (var signalJson in decoded) {
      final signal = TradeSignal.fromJson(signalJson as Map<String, dynamic>);
      await SupabaseService.saveSignal(signal);
    }
  } catch (e) {
    // Log error but don't throw (graceful degradation)
    print('Error saving signals to Supabase: $e');
  }
}
