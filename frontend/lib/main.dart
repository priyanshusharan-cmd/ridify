import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/health_service.dart';
import 'core/theme_provider.dart';
import 'core/app_theme.dart';
import 'core/socket_service.dart';
import 'screens/splash_screen.dart';
import 'core/user_provider.dart';
import 'core/rides_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final Set<String> navigatedRides = {};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env not found — using compile-time constants or defaults
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User came back to the app from background
      _pingBackend();
      // Force socket reconnection or heartbeat check
      SocketService().handleAppResumed();
    }
  }

  void _pingBackend() {
    HealthService().pingServer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => RidesProvider()),
          ],
          child: MaterialApp(
            scrollBehavior: AppScrollBehavior(),
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Ridify',
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
