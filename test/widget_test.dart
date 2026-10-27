import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:distance_monitor/app/app.dart';
import 'package:distance_monitor/controllers/distance_controller.dart';
import 'package:distance_monitor/models/distance_reading.dart';
import 'package:distance_monitor/models/monitor_settings.dart';
import 'package:distance_monitor/services/esp32_service.dart';
import 'package:distance_monitor/services/settings_service.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
    const Size(800, 360),
    const Size(600, 960),
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'Dashboard ${size.width}x${size.height} text $scale has no overflow',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final controller = DistanceController(
            settings: const MonitorSettings(animations: false),
            service: Esp32Service(
              clientFactory: () => MockClient(
                (_) async =>
                    http.Response('{"distance_cm":22.4,"sensor_ok":true}', 200),
              ),
            ),
          );
          await tester.pumpWidget(
            DistanceApp(controller: controller, store: SettingsService()),
          );
          await tester.pump();
          await tester.pump();
          expect(find.text('22.4'), findsOneWidget);
          expect(find.text('cm'), findsOneWidget);
          expect(find.text('Demo Mode'), findsNothing);
          expect(controller.status, DistanceStatus.caution);
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 8; i++) {
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -400),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('Settings validates and saves configuration', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = DistanceController(
      settings: const MonitorSettings(animations: false),
      service: Esp32Service(
        clientFactory: () => MockClient(
          (_) async =>
              http.Response('{"distance_cm":22.4,"sensor_ok":true}', 200),
        ),
      ),
    );
    await tester.pumpWidget(
      DistanceApp(controller: controller, store: SettingsService()),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final host = find.widgetWithText(TextFormField, 'IP address or hostname');
    await tester.enterText(host, '999.1.1.1');
    await tester.ensureVisible(find.text('Save configuration'));
    await tester.tap(find.text('Save configuration'));
    await tester.pump();
    expect(find.text('Enter a valid IPv4 address'), findsOneWidget);
    await tester.ensureVisible(host);
    await tester.enterText(host, '192.168.1.77');
    await tester.ensureVisible(find.text('Save configuration'));
    await tester.tap(find.text('Save configuration'));
    await tester.pumpAndSettle();
    expect(controller.settings.host, '192.168.1.77');
    expect((await SettingsService().load()).host, '192.168.1.77');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Loads settings saved before demo mode was removed', () async {
    SharedPreferences.setMockInitialValues({
      'monitor_settings':
          '{"host":"192.168.1.77","port":8080,"interval":750,"demo":true,"animations":false,"gaugeMax":200}',
    });

    final settings = await SettingsService().load();

    expect(settings.host, '192.168.1.77');
    expect(settings.port, 8080);
    expect(settings.intervalMs, 750);
    expect(settings.animations, isFalse);
    expect(settings.gaugeMax, 200);
  });
}
