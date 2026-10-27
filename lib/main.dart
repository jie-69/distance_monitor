import 'package:flutter/material.dart';
import 'app/app.dart';
import 'controllers/distance_controller.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsService();
  final settings = await store.load();
  runApp(
    DistanceApp(
      controller: DistanceController(settings: settings),
      store: store,
    ),
  );
}
