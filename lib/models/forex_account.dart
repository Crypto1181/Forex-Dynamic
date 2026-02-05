class ForexAccount {
  final String id;
  final String name;
  final String brokerTimeOffset; // Format: "-02:15" or "+03:00"
  final double defaultLotSize;
  final double defaultDailyLot; // Lot size for daily re-entry trades
  final String? comment;
  final String brand;
  final int colorValue; // For UI color coding

  ForexAccount({
    required this.id,
    required this.name,
    required this.brokerTimeOffset,
    required this.defaultLotSize,
    this.defaultDailyLot = 0.02,
    this.comment,
    required this.brand,
    required this.colorValue,
  });

  factory ForexAccount.fromJson(Map<String, dynamic> json) {
    return ForexAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      brokerTimeOffset: json['brokerTimeOffset'] as String,
      defaultLotSize: (json['defaultLotSize'] as num).toDouble(),
      defaultDailyLot: (json['defaultDailyLot'] as num?)?.toDouble() ?? 0.02,
      comment: json['comment'] as String?,
      brand: json['brand'] as String,
      colorValue: json['colorValue'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brokerTimeOffset': brokerTimeOffset,
      'defaultLotSize': defaultLotSize,
      'defaultDailyLot': defaultDailyLot,
      if (comment != null) 'comment': comment,
      'brand': brand,
      'colorValue': colorValue,
    };
  }

  ForexAccount copyWith({
    String? id,
    String? name,
    String? brokerTimeOffset,
    double? defaultLotSize,
    double? defaultDailyLot,
    String? comment,
    String? brand,
    int? colorValue,
  }) {
    return ForexAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      brokerTimeOffset: brokerTimeOffset ?? this.brokerTimeOffset,
      defaultLotSize: defaultLotSize ?? this.defaultLotSize,
      defaultDailyLot: defaultDailyLot ?? this.defaultDailyLot,
      comment: comment ?? this.comment,
      brand: brand ?? this.brand,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

