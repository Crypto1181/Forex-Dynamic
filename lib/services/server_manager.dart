import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/api_response.dart';
import 'signal_service.dart';

class ServerManager {
  final SignalService signalService;
  HttpServer? _httpServer;
  ServerSocket? _tcpServer;
  bool _isRunning = false;
  int _port = 8080;
  String _connectionType = 'REST'; // REST, WebSocket, or TCP

  ServerManager(this.signalService);

  bool get isRunning => _isRunning;
  int get port => _port;
  String get connectionType => _connectionType;

  // Start the server based on connection type
  Future<void> startServer({
    required int port,
    required String connectionType,
    String? apiKey,
  }) async {
    if (_isRunning) {
      await stopServer();
    }

    _port = port;
    _connectionType = connectionType;

    try {
      switch (connectionType) {
        case 'REST':
          await _startRestServer(port, apiKey);
          break;
        case 'WebSocket':
          await _startWebSocketServer(port, apiKey);
          break;
        case 'TCP':
          await _startTcpServer(port, apiKey);
          break;
        default:
          throw Exception('Unknown connection type: $connectionType');
      }
      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  // Start REST API server
  Future<void> _startRestServer(int port, String? apiKey) async {
    try {
      print('🔄 Starting REST server on port $port...');
      
      final handler = Pipeline()
          .addMiddleware(corsHeaders())
          .addMiddleware(logRequests())
          .addHandler(_handleRequest(apiKey));

      // Try binding to any IPv4 (0.0.0.0) for cloud hosting compatibility
      try {
        _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        print('✅ REST API server running on port $port');
        print('   Local: http://localhost:$port');
        print('   Health check: http://localhost:$port/');
        print('   Server address: ${_httpServer!.address.address}:${_httpServer!.port}');
      } catch (e) {
        // If localhost fails, try anyIPv4
        print('⚠️  localhost binding failed, trying anyIPv4: $e');
        _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        print('✅ REST API server running on port $port (anyIPv4)');
        print('   Local: http://localhost:$port');
        print('   Network: http://${_httpServer!.address.address}:$port');
      }
    } catch (e) {
      print('❌ Failed to start REST server: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Error details: ${e.toString()}');
      if (e.toString().contains('Address already in use') || 
          e.toString().contains('bind') ||
          e.toString().contains('EADDRINUSE')) {
        throw Exception('Port $port is already in use. Try a different port or stop the other service.');
      }
      if (e.toString().contains('Permission denied') || 
          e.toString().contains('EACCES')) {
        throw Exception('Permission denied. Ports below 1024 require root. Use port 8080 or higher.');
      }
      rethrow;
    }
  }

  // Start WebSocket server
  Future<void> _startWebSocketServer(int port, String? apiKey) async {
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(logRequests())
        .addHandler(
          webSocketHandler((WebSocketChannel channel) {
            channel.stream.listen(
              (message) {
                try {
                  final jsonData = jsonDecode(message as String);
                  final response = signalService.processSignal(jsonData);
                  channel.sink.add(jsonEncode(response.toJson()));
                } catch (e) {
                  final errorResponse = ApiResponse.error(
                    'Invalid JSON format: ${e.toString()}',
                    code: 'INVALID_JSON',
                  );
                  channel.sink.add(jsonEncode(errorResponse.toJson()));
                }
              },
              onError: (error) {
                print('WebSocket error: $error');
              },
              onDone: () {
                print('WebSocket connection closed');
              },
            );
          }),
        );

    _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('WebSocket server running on port $port');
  }

  // Start TCP Socket server
  Future<void> _startTcpServer(int port, String? apiKey) async {
    _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    print('TCP Socket server running on port $port');

    _tcpServer!.listen((Socket client) {
      print('TCP client connected');
      String buffer = '';

      client.listen(
        (data) {
          try {
            buffer += utf8.decode(data);
            // Try to parse complete JSON messages
            final lines = buffer.split('\n');
            buffer = lines.removeLast(); // Keep incomplete line in buffer

            for (final line in lines) {
              if (line.trim().isEmpty) continue;
              final jsonData = jsonDecode(line.trim());
              final response = signalService.processSignal(jsonData);
              client.add(utf8.encode(jsonEncode(response.toJson()) + '\n'));
            }
          } catch (e) {
            final errorResponse = ApiResponse.error(
              'Invalid data format: ${e.toString()}',
              code: 'INVALID_FORMAT',
            );
            client.add(utf8.encode(jsonEncode(errorResponse.toJson()) + '\n'));
          }
        },
        onError: (error) {
          print('TCP client error: $error');
          client.close();
        },
        onDone: () {
          print('TCP client disconnected');
          client.close();
        },
      );
    });
  }

  // Handle HTTP requests for REST API
  FutureOr<Response> Function(Request) _handleRequest(String? apiKey) {
    return (Request request) async {
      // Handle CORS preflight
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }

      // Check authentication if API key is set
      if (apiKey != null && apiKey.isNotEmpty) {
        final authHeader = request.headers['authorization'];
        final queryKey = request.url.queryParameters['apiKey'];
        if (authHeader != 'Bearer $apiKey' && queryKey != apiKey) {
          return Response.forbidden(
            jsonEncode(ApiResponse.error('Unauthorized', code: 'UNAUTHORIZED').toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // Handle GET requests (for EA to poll signals)
      if (request.method == 'GET') {
        // Normalize path - ensure it starts with / for consistent matching
        var path = request.url.path;
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        // Remove trailing slash for consistent matching
        path = path.replaceAll(RegExp(r'/$'), '');
        print('🔍 GET request to path: "${request.url.path}" -> normalized: "$path"'); // Debug logging
        
        // GET /signals - Get all signals with GMT creation time and message IDs
        if (path == '/signals') {
          print('✅ Matched /signals endpoint'); // Debug logging
          final signals = signalService.signals;
          if (signals.isEmpty) {
            return Response.ok(
              jsonEncode({
                'status': 'success',
                'message': 'No signals available',
                'signals': [],
              }),
              headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
              },
            );
          }
          
          // Return all signals with GMT creation time and message IDs
          final signalsList = signals.map((signal) {
            final signalJson = signal.toJson();
            // Convert receivedAt to GMT (UTC)
            final gmtTime = signal.receivedAt.toUtc();
            // Format as ISO 8601 in GMT
            signalJson['creationTimeGMT'] = gmtTime.toIso8601String();
            // Ensure messageId is present (use tradeId)
            signalJson['messageId'] = signal.tradeId ?? '';
            return signalJson;
          }).toList();
          
          return Response.ok(
            jsonEncode({
              'status': 'success',
              'message': 'Signals retrieved',
              'signals': signalsList,
              'count': signalsList.length,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          );
        }
        
        // GET / - Health check
        if (path == '/' || path.isEmpty || path == '') {
          print('✅ Matched / health check endpoint'); // Debug logging
          return Response.ok(
            jsonEncode({
              'status': 'success',
              'message': 'Trade Signal API is running',
              'version': '1.0.0',
            }),
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          );
        }
        
        print('❌ Path not matched: "$path"'); // Debug logging
        return Response.notFound(
          jsonEncode(ApiResponse.error('Endpoint not found', code: 'NOT_FOUND').toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Handle POST requests (for receiving signals)
      if (request.method == 'POST') {
        try {
          final body = await request.readAsString();
          final jsonData = jsonDecode(body);
          final response = signalService.processSignal(jsonData);
          return Response.ok(
            jsonEncode(response.toJson()),
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          );
        } catch (e) {
          final errorResponse = ApiResponse.error(
            'Invalid JSON format: ${e.toString()}',
            code: 'INVALID_JSON',
          );
          return Response.badRequest(
            body: jsonEncode(errorResponse.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      return Response(
        405,
        body: jsonEncode(ApiResponse.error('Method not allowed', code: 'METHOD_NOT_ALLOWED').toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    };
  }

  // Stop the server
  Future<void> stopServer() async {
    if (_httpServer != null) {
      await _httpServer!.close();
      _httpServer = null;
    }
    if (_tcpServer != null) {
      await _tcpServer!.close();
      _tcpServer = null;
    }
    _isRunning = false;
    print('Server stopped');
  }
  
  // Test if server is actually responding
  Future<bool> testLocalConnection() async {
    try {
      final client = HttpClient();
      final request = await client.get('localhost', _port, '/')
          .timeout(const Duration(seconds: 2));
      final response = await request.close();
      await response.transform(utf8.decoder).join(); // Read body to complete request
      client.close();
      final isOk = response.statusCode == 200;
      print('Local connection test: ${isOk ? "✅ OK" : "❌ Failed"} (${response.statusCode})');
      return isOk;
    } catch (e) {
      print('Local connection test failed: $e');
      return false;
    }
  }
}

