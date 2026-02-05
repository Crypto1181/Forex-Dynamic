import 'dart:async';
import 'dart:convert';
import '../models/trade_signal.dart';
import '../models/api_response.dart';
import 'package:uuid/uuid.dart';
import 'signal_service_storage_stub.dart'
    if (dart.library.ui) 'signal_service_storage_flutter.dart';
import 'supabase_service.dart';

class SignalService {
  final List<TradeSignal> _signals = [];
  final StreamController<TradeSignal> _signalController =
      StreamController<TradeSignal>.broadcast();
  final Uuid _uuid = const Uuid();
  static const String _signalsKey = 'saved_trade_signals';

  // Stream to listen for new signals
  Stream<TradeSignal> get signalStream => _signalController.stream;

  // Get all signals
  List<TradeSignal> get signals => List.unmodifiable(_signals);

  // Initialize and load saved signals
  Future<void> initialize() async {
    // Initialize Supabase first
    try {
      await SupabaseService.initialize();
    } catch (e) {
      print('Warning: Supabase initialization failed: $e');
    }

    // Try to load from Supabase first (Server relies on this)
    bool loadedFromSupabase = false;
    if (SupabaseService.isInitialized) {
      try {
        final signals = await SupabaseService.fetchSignals();
        if (signals.isNotEmpty) {
          _signals.clear();
          _signals.addAll(signals);
          loadedFromSupabase = true;
          print('Loaded ${_signals.length} signals from Supabase');
        }
      } catch (e) {
        print('Warning: Failed to load from Supabase: $e');
      }
    }

    // If not loaded from Supabase (or we want to merge/fallback), load from local storage
    // On Server, loadSignals() is a stub (does nothing), so this is fine.
    // On App, if offline, this loads from cache.
    if (!loadedFromSupabase) {
      await loadSignals();
    }
  }

  // Load signals from storage (only works in Flutter)
  Future<void> loadSignals() async {
    try {
      final signalsJson = await getStoredSignals(_signalsKey);
      if (signalsJson != null) {
        final List<dynamic> decoded = json.decode(signalsJson);
        _signals.clear();
        _signals.addAll(
          decoded.map(
            (json) => TradeSignal.fromJson(json as Map<String, dynamic>),
          ),
        );
        // Sort by receivedAt descending (newest first)
        _signals.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      }
    } catch (e) {
      // If loading fails, start with empty list (server environment or error)
      _signals.clear();
    }
  }

  // Save signals to storage (only works in Flutter)
  Future<void> _saveSignals() async {
    try {
      final signalsJson = json.encode(
        _signals.map((signal) => signal.toJson()).toList(),
      );
      await saveSignals(_signalsKey, signalsJson);
    } catch (e) {
      // Silently fail - data will be lost but app won't crash (server environment)
    }
  }

  // Save individual signal to Supabase
  Future<void> _saveSignalToSupabase(TradeSignal signal) async {
    try {
      if (SupabaseService.isInitialized) {
        await SupabaseService.saveSignal(signal);
      }
    } catch (e) {
      print('Error saving signal to Supabase: $e');
      // Don't throw - allow app to continue
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
    // Save to Supabase directly for better performance
    _saveSignalToSupabase(draft);
    _saveSignals(); // Also save to storage for compatibility
    return draft;
  }

  /// Duplicates an existing signal as a new draft (new id, same data).
  TradeSignal duplicateSignal(TradeSignal signal) {
    final duplicate = signal.copyWith(
      tradeId: null,
      receivedAt: DateTime.now(),
      isDraft: true,
    );
    return addDraftSignal(duplicate);
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

      // Use existing ID if available, otherwise generate new one
      final tradeId = signal.tradeId != null && signal.tradeId!.isNotEmpty
          ? signal.tradeId!
          : _uuid.v4();

      final signalWithId = signal.copyWith(tradeId: tradeId, isDraft: false);

      // Check if signal with this ID already exists
      final existingIndex = _signals.indexWhere((s) => s.tradeId == tradeId);

      if (existingIndex != -1) {
        // Update existing signal
        _signals[existingIndex] = signalWithId;
        // Move to top to show it's the latest action
        _signals.removeAt(existingIndex);
        _signals.insert(0, signalWithId);
      } else {
        // Add to list
        _signals.insert(0, signalWithId); // Add to beginning for newest first
      }

      // Emit to stream
      _signalController.add(signalWithId);

      // Save to Supabase directly
      _saveSignalToSupabase(signalWithId);
      // Also save to storage for compatibility
      _saveSignals();

      return ApiResponse.success(tradeId: tradeId);
    } catch (e) {
      return ApiResponse.error(
        'Failed to process signal: ${e.toString()}',
        code: 'PROCESSING_ERROR',
      );
    }
  }

  // Delete a signal by ID
  Future<bool> deleteSignal(String id) async {
    final index = _signals.indexWhere((signal) => signal.tradeId == id);
    if (index != -1) {
      _signals.removeAt(index);
      // Delete from Supabase
      try {
        if (SupabaseService.isInitialized) {
          await SupabaseService.deleteSignal(id);
        }
      } catch (e) {
        print('Error deleting signal from Supabase: $e');
      }
      await _saveSignals();
      return true;
    }
    return false;
  }

  // Update a signal
  Future<bool> updateSignal(String id, TradeSignal updatedSignal) async {
    final index = _signals.indexWhere((signal) => signal.tradeId == id);
    if (index != -1) {
      final signalWithId = updatedSignal.copyWith(tradeId: id);
      _signals[index] = signalWithId;
      // Update in Supabase
      try {
        if (SupabaseService.isInitialized) {
          await SupabaseService.updateSignal(signalWithId);
        }
      } catch (e) {
        print('Error updating signal in Supabase: $e');
      }
      await _saveSignals();
      return true;
    }
    return false;
  }

  // Clear all signals
  Future<void> clearSignals() async {
    _signals.clear();
    // Clear from Supabase
    try {
      if (SupabaseService.isInitialized) {
        await SupabaseService.clearAllSignals();
      }
    } catch (e) {
      print('Error clearing signals from Supabase: $e');
    }
    await _saveSignals(); // Clear from storage too
  }

  // Dispose resources
  void dispose() {
    _signalController.close();
  }
}
