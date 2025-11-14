import 'dart:io';
import '../lib/services/signal_service.dart';
import '../lib/services/server_manager.dart';

void main() async {
  final signalService = SignalService();
  final serverManager = ServerManager(signalService);

  // Get port from environment variable (Render provides this)
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  try {
    await serverManager.startServer(
      port: port,
      connectionType: 'REST',
      apiKey: null,
    );

    print('✅ Server running on port $port');
    print('Server is ready to receive signals!');
    print('Health check: http://0.0.0.0:$port/');
    
    // Keep the process alive (wait indefinitely)
    await Future.delayed(Duration(days: 365));
  } catch (e, stackTrace) {
    print('❌ Failed to start server: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

