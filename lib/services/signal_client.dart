import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/trade_signal.dart';
import '../models/api_response.dart';

class SignalClient {
  final String host;
  final int port;
  final String connectionType; // REST, WebSocket, TCP
  final String? apiKey;
  final bool useHttps;

  SignalClient({
    required this.host,
    required this.port,
    required this.connectionType,
    this.apiKey,
    this.useHttps = false,
  });

  // Send signal via REST API
  Future<ApiResponse> sendSignalRest(TradeSignal signal) async {
    try {
      final protocol = useHttps ? 'https' : 'http';
      final uri = Uri.parse('$protocol://$host:$port/');
      final headers = {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      };

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(signal.toJson()),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.fromJson(json);
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.fromJson(json);
      }
    } catch (e) {
      return ApiResponse.error(
        'Failed to send signal: ${e.toString()}',
        code: 'NETWORK_ERROR',
      );
    }
  }

  // Send signal via WebSocket
  Future<ApiResponse> sendSignalWebSocket(TradeSignal signal) async {
    try {
      final protocol = useHttps ? 'wss' : 'ws';
      final uri = Uri.parse('$protocol://$host:$port/');
      final channel = WebSocketChannel.connect(uri);

      // Send signal
      channel.sink.add(jsonEncode(signal.toJson()));

      // Wait for response (with timeout)
      final response = await channel.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('No response from server'),
      );

      channel.sink.close();
      final json = jsonDecode(response as String) as Map<String, dynamic>;
      return ApiResponse.fromJson(json);
    } catch (e) {
      return ApiResponse.error(
        'Failed to send signal: ${e.toString()}',
        code: 'NETWORK_ERROR',
      );
    }
  }

  // Send signal via TCP Socket
  Future<ApiResponse> sendSignalTcp(TradeSignal signal) async {
    try {
      final socket = await Socket.connect(host, port);
      final completer = Completer<ApiResponse>();

      socket.listen(
        (data) {
          final response = utf8.decode(data);
          final json = jsonDecode(response.trim()) as Map<String, dynamic>;
          completer.complete(ApiResponse.fromJson(json));
          socket.close();
        },
        onError: (error) {
          completer.completeError(error);
          socket.close();
        },
      );

      // Send signal
      socket.add(utf8.encode(jsonEncode(signal.toJson()) + '\n'));

      // Wait for response with timeout
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          socket.close();
          throw TimeoutException('No response from server');
        },
      );
    } catch (e) {
      return ApiResponse.error(
        'Failed to send signal: ${e.toString()}',
        code: 'NETWORK_ERROR',
      );
    }
  }

  // Main method to send signal (chooses method based on connection type)
  Future<ApiResponse> sendSignal(TradeSignal signal) async {
    switch (connectionType) {
      case 'REST':
        return await sendSignalRest(signal);
      case 'WebSocket':
        return await sendSignalWebSocket(signal);
      case 'TCP':
        return await sendSignalTcp(signal);
      default:
        return ApiResponse.error(
          'Unknown connection type: $connectionType',
          code: 'INVALID_TYPE',
        );
    }
  }
}

