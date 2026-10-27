import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/distance_controller.dart';
import '../services/settings_service.dart';
import '../screens/dashboard_screen.dart';

const navy = Color(0xFF0B2345);
const secondaryText = Color(0xFF667085);

class DistanceApp extends StatefulWidget {
  const DistanceApp({super.key, required this.controller, required this.store});
  final DistanceController controller;
  final SettingsService store;
  @override
  State<DistanceApp> createState() => _DistanceAppState();
}

class _DistanceAppState extends State<DistanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.start();
    } else {
      widget.controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Distance Monitor',
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF4F7FC),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: child!,
    ),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: navy),
      scaffoldBackgroundColor: const Color(0xFFF4F7FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: navy),
        bodyLarge: TextStyle(color: navy),
      ),
    ),
    home: DashboardScreen(controller: widget.controller, store: widget.store),
  );
}
