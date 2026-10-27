import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:distance_monitor/models/distance_reading.dart';
import 'package:distance_monitor/models/monitor_settings.dart';
import 'package:distance_monitor/controllers/distance_controller.dart';
import 'package:distance_monitor/services/esp32_service.dart';

void main() {
  test('Exact threshold boundaries and unavailable values', () {
    for (final value in [10.0, 14.9]) {
      expect(classifyDistance(value), DistanceStatus.danger);
    }
    for (final value in [15.0, 22.4, 30.0]) {
      expect(classifyDistance(value), DistanceStatus.caution);
    }
    for (final value in [30.1, 50.0, 200.0]) {
      expect(classifyDistance(value), DistanceStatus.safe);
    }
    for (final value in [null, -1.0, double.nan, double.infinity]) {
      expect(classifyDistance(value), DistanceStatus.noData);
    }
  });
  test('Host validation rejects malformed addresses and URLs', () {
    for (final host in ['esp32.local', '192.168.1.50', 'sensor-1']) {
      expect(MonitorSettings.validateHost(host), isNull);
    }
    for (final host in [
      '',
      '999.1.1.1',
      '1.2.3',
      'http://esp32.local',
      '-bad.local',
      'host/path',
    ]) {
      expect(MonitorSettings.validateHost(host), isNotNull);
    }
  });
  test('Valid HTTP contract', () async {
    final service = Esp32Service(
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/distance');
        return http.Response('{"distance_cm":22.4,"sensor_ok":true}', 200);
      }),
    );
    expect((await service.read(const MonitorSettings())).distance, 22.4);
  });
  for (final body in [
    '{}',
    '{"sensor_ok":true}',
    '{"sensor_ok":false,"distance_cm":50}',
    '{"sensor_ok":true,"distance_cm":-1}',
    '{"sensor_ok":true,"distance_cm":"NaN"}',
    'invalid json',
  ]) {
    test('Reject invalid response $body', () async {
      final service = Esp32Service(
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.read(const MonitorSettings()),
        throwsFormatException,
      );
    });
  }
  test('Server error', () async {
    final service = Esp32Service(
      clientFactory: () => MockClient((_) async => http.Response('error', 503)),
    );
    await expectLater(service.read(const MonitorSettings()), throwsStateError);
  });
  test('Timeout closes a pending request', () async {
    final service = Esp32Service(
      timeout: const Duration(milliseconds: 5),
      clientFactory: () => MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      service.read(const MonitorSettings()),
      throwsA(isA<TimeoutException>()),
    );
  });
  testWidgets(
    'Sequential polling, disconnect, reconnect, pause and stale data',
    (tester) async {
      var now = DateTime(2026);
      var requests = 0;
      var pending = Completer<http.Response>();
      final service = Esp32Service(
        clientFactory: () => MockClient((_) {
          requests++;
          return pending.future;
        }),
      );
      final c = DistanceController(
        settings: const MonitorSettings(),
        service: service,
        clock: () => now,
      );
      c.start();
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 1);
      expect(c.link, LinkState.connecting);
      pending.complete(http.Response('offline', 503));
      await tester.pump();
      expect(c.link, LinkState.disconnected);
      expect(c.status, DistanceStatus.noData);
      pending = Completer<http.Response>();
      c.retry();
      pending.complete(
        http.Response('{"distance_cm":50,"sensor_ok":true}', 200),
      );
      await tester.pump();
      expect(c.link, LinkState.connected);
      expect(c.status, DistanceStatus.safe);
      now = DateTime.now().add(const Duration(seconds: 20));
      expect(c.distance, isNull);
      c.pause();
      expect(c.link, LinkState.paused);
      expect(c.status, DistanceStatus.noData);
      final count = requests;
      await tester.pump(const Duration(seconds: 10));
      expect(requests, count);
      c.dispose();
    },
  );
  testWidgets('Old response cannot replace new configuration', (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final c = DistanceController(
      settings: const MonitorSettings(),
      service: Esp32Service(
        clientFactory: () => MockClient((_) {
          requests++;
          return requests == 1
              ? pending.future
              : Future.value(
                  http.Response('{"distance_cm":40,"sensor_ok":true}', 200),
                );
        }),
      ),
    );
    c.start();
    await tester.pump();
    c.configure(const MonitorSettings(host: '192.168.1.77'));
    pending.complete(
      http.Response('{"distance_cm":300,"sensor_ok":true}', 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(c.link, LinkState.connected);
    expect(c.distance, 40);
    c.dispose();
  });
}
