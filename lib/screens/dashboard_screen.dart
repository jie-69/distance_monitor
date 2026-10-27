import 'package:flutter/material.dart';
import '../app/app.dart';
import '../controllers/distance_controller.dart';
import '../services/settings_service.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/distance_gauge.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.store,
  });
  final DistanceController controller;
  final SettingsService store;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: navy,
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_tethering,
                    size: 32,
                    color: Color(0xFF64C7FF),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Distance Monitor',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 23,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsScreen(
                          controller: controller,
                          store: store,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  16,
                  14,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListenableBuilder(
                          listenable: controller,
                          builder: (_, child) =>
                              ConnectionCard(controller: controller),
                        ),
                        const SizedBox(height: 14),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (context, child) => Panel(
                            child: Column(
                              children: [
                                DistanceGauge(
                                  distance: controller.distance,
                                  status: controller.status,
                                  maximum: controller.settings.gaugeMax,
                                  animations: controller.settings.animations,
                                ),
                                const SizedBox(height: 18),
                                StatusCard(
                                  status: controller.status,
                                  animations: controller.settings.animations,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (_, child) =>
                              DistanceGuide(active: controller.status),
                        ),
                        const SizedBox(height: 14),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (_, child) =>
                              LiveDataCard(controller: controller),
                        ),
                        const SizedBox(height: 14),
                        const Panel(
                          child: Row(
                            children: [
                              Icon(Icons.wifi, color: navy, size: 30),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'This app updates the distance in real time from the ESP32 over WiFi.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
