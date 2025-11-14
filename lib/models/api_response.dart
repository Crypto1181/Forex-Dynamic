class ApiResponse {
  final String status; // "success" or "error"
  final String message;
  final String? tradeId;
  final String? code; // Error code if status is "error"

  ApiResponse({
    required this.status,
    required this.message,
    this.tradeId,
    this.code,
  });

  factory ApiResponse.success({String? message, String? tradeId}) {
    return ApiResponse(
      status: 'success',
      message: message ?? 'Trade signal received',
      tradeId: tradeId,
    );
  }

  factory ApiResponse.error(String message, {String? code}) {
    return ApiResponse(
      status: 'error',
      message: message,
      code: code,
    );
  }

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      tradeId: json['tradeId'] as String?,
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      if (tradeId != null) 'tradeId': tradeId,
      if (code != null) 'code': code,
    };
  }
}

