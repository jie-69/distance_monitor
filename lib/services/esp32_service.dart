import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/distance_reading.dart';
import '../models/monitor_settings.dart';

class Esp32Service {
  Esp32Service({
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 3),
  }) : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  final Duration timeout;
  http.Client? _active;
  Future<DistanceReading> read(MonitorSettings settings) async {
    final client = _factory();
    _active = client;
    try {
      final response = await client.get(settings.endpoint).timeout(timeout);
      if (response.statusCode != 200) {
        throw StateError('ESP32 returned HTTP ${response.statusCode}');
      }
      return DistanceReading.fromJson(
        jsonDecode(response.body),
        DateTime.now(),
      );
    } finally {
      client.close();
      if (identical(_active, client)) _active = null;
    }
  }

  void cancel() {
    _active?.close();
    _active = null;
  }
}
