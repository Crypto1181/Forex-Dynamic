class TradeSignal {
  final String symbol;
  final String direction; // "BUY" or "SELL"
  final String entryTime; // "YYYY-MM-DD HH:MM:SS"
  final double entryPrice; // Entry price (0 if not specified)
  final double tp; // Take Profit in pips
  final double sl; // Stop Loss in pips
  final String? tpCondition1; // Optional time condition "HH:MM"
  final String? tpCondition2; // Optional time condition "HH:MM"
  final double? newTP; // Optional new TP value
  final double lot; // Lot size
  final bool isDaily; // Boolean indicating if this is a daily trade
  final double? dailyTP; // Daily TP value if applicable
  final double? dailyLot; // Daily lot size if applicable
  final String accountName; // Name of the account/EA
  final String brand; // Trade brand identifier
  final String entryType; // "TIME" or "PRICE"
  final String? tradeId; // Unique ID for the trade
  final DateTime receivedAt; // When the signal was received
  final bool isDraft; // Indicates if this is a saved draft (not yet sent)

  TradeSignal({
    required this.symbol,
    required this.direction,
    required this.entryTime,
    this.entryPrice = 0.0,
    required this.tp,
    required this.sl,
    this.tpCondition1,
    this.tpCondition2,
    this.newTP,
    required this.lot,
    required this.isDaily,
    this.dailyTP,
    this.dailyLot,
    required this.accountName,
    required this.brand,
    this.entryType = 'TIME',
    this.tradeId,
    DateTime? receivedAt,
    this.isDraft = false,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory TradeSignal.fromJson(Map<String, dynamic> json) {
    return TradeSignal(
      symbol: json['symbol'] as String,
      direction: json['direction'] as String,
      entryTime: json['entryTime'] as String,
      entryPrice: json['entryPrice'] != null
          ? (json['entryPrice'] as num).toDouble()
          : 0.0,
      tp: (json['tp'] as num).toDouble(),
      sl: (json['sl'] as num).toDouble(),
      tpCondition1: json['tpCondition1'] as String?,
      tpCondition2: json['tpCondition2'] as String?,
      newTP: json['newTP'] != null ? (json['newTP'] as num).toDouble() : null,
      lot: (json['lot'] as num).toDouble(),
      isDaily: json['isDaily'] as bool? ?? false,
      dailyTP: json['dailyTP'] != null
          ? (json['dailyTP'] as num).toDouble()
          : null,
      dailyLot: json['dailyLot'] != null
          ? (json['dailyLot'] as num).toDouble()
          : null,
      accountName: json['accountName'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      entryType: json['entryType'] as String? ?? 'TIME',
      tradeId: json['tradeId'] as String?,
      receivedAt: json['receivedAt'] != null
          ? DateTime.parse(json['receivedAt'] as String)
          : DateTime.now(),
      isDraft: json['isDraft'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'direction': direction,
      'entryTime': entryTime,
      'entryPrice': entryPrice,
      'tp': tp,
      'sl': sl,
      if (tpCondition1 != null) 'tpCondition1': tpCondition1,
      if (tpCondition2 != null) 'tpCondition2': tpCondition2,
      if (newTP != null) 'newTP': newTP,
      'lot': lot,
      'isDaily': isDaily,
      if (dailyTP != null) 'dailyTP': dailyTP,
      if (dailyLot != null) 'dailyLot': dailyLot,
      'accountName': accountName,
      'brand': brand,
      'entryType': entryType,
      if (tradeId != null) 'tradeId': tradeId,
      'receivedAt': receivedAt.toIso8601String(),
      'isDraft': isDraft,
    };
  }

  TradeSignal copyWith({
    String? symbol,
    String? direction,
    String? entryTime,
    double? entryPrice,
    double? tp,
    double? sl,
    String? tpCondition1,
    String? tpCondition2,
    double? newTP,
    double? lot,
    bool? isDaily,
    double? dailyTP,
    double? dailyLot,
    String? accountName,
    String? brand,
    String? entryType,
    String? tradeId,
    DateTime? receivedAt,
    bool? isDraft,
  }) {
    return TradeSignal(
      symbol: symbol ?? this.symbol,
      direction: direction ?? this.direction,
      entryTime: entryTime ?? this.entryTime,
      entryPrice: entryPrice ?? this.entryPrice,
      tp: tp ?? this.tp,
      sl: sl ?? this.sl,
      tpCondition1: tpCondition1 ?? this.tpCondition1,
      tpCondition2: tpCondition2 ?? this.tpCondition2,
      newTP: newTP ?? this.newTP,
      lot: lot ?? this.lot,
      isDaily: isDaily ?? this.isDaily,
      dailyTP: dailyTP ?? this.dailyTP,
      dailyLot: dailyLot ?? this.dailyLot,
      accountName: accountName ?? this.accountName,
      brand: brand ?? this.brand,
      entryType: entryType ?? this.entryType,
      tradeId: tradeId ?? this.tradeId,
      receivedAt: receivedAt ?? this.receivedAt,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  // Validation method
  String? validate() {
    if (symbol.isEmpty) return 'Symbol is required';
    if (direction != 'BUY' && direction != 'SELL') {
      return 'Direction must be BUY or SELL';
    }
    if (entryTime.isEmpty) return 'Entry time is required';
    if (!isDraft) {
      if (accountName.isEmpty) return 'Account name is required';
      if (brand.isEmpty) return 'Brand is required';
    }
    return null;
  }
}
