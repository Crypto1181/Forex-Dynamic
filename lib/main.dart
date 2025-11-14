import 'package:flutter/material.dart';
import 'services/signal_service.dart';
import 'services/server_manager.dart';
import 'services/account_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forex Trade Signal API',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AppHome(),
    );
  }
}

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final SignalService signalService;
  late final ServerManager serverManager;
  late final AccountService accountService;

  @override
  void initState() {
    super.initState();
    signalService = SignalService();
    serverManager = ServerManager(signalService);
    accountService = AccountService();
  }

  @override
  void dispose() {
    serverManager.stopServer();
    signalService.dispose();
    accountService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      signalService: signalService,
      serverManager: serverManager,
      accountService: accountService,
    );
  }
}
