import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/distance_reading.dart';
import '../models/monitor_settings.dart';
import '../services/esp32_service.dart';

enum LinkState { connecting, connected, disconnected, paused }

class DistanceController extends ChangeNotifier {
  DistanceController({
    required this.settings,
    Esp32Service? service,
    DateTime Function()? clock,
  }) : _service = service ?? Esp32Service(),
       _clock = clock ?? DateTime.now;
  MonitorSettings settings;
  final Esp32Service _service;
  final DateTime Function() _clock;
  final ValueNotifier<int> ageTick = ValueNotifier(0);
  Timer? _pollTimer, _ageTimer;
  DistanceReading? reading;
  DateTime? lastSuccess;
  LinkState link = LinkState.disconnected;
  String? error;
  bool _active = false, _disposed = false, _busy = false;
  int _generation = 0, _failures = 0;
  Duration get staleThreshold =>
      Duration(milliseconds: max(5000, settings.intervalMs * 3));
  double? get distance =>
      _active &&
          reading != null &&
          _clock().difference(reading!.receivedAt) <= staleThreshold
      ? reading!.distance
      : null;
  DistanceStatus get status => classifyDistance(distance);
  String get ageLabel {
    if (lastSuccess == null) return 'No readings yet';
    final seconds = max(0, _clock().difference(lastSuccess!).inSeconds);
    return seconds < 1 ? 'Just now' : '${seconds}s ago';
  }

  void start() {
    if (_disposed || _active) return;
    _active = true;
    _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ageTick.value++;
      if (reading != null && distance == null) {
        reading = null;
        link = LinkState.disconnected;
        error = 'Reading expired. Reconnecting…';
        notifyListeners();
      }
    });
    retry();
  }

  void pause() {
    _active = false;
    _generation++;
    _pollTimer?.cancel();
    _ageTimer?.cancel();
    _service.cancel();
    reading = null;
    link = LinkState.paused;
    notifyListeners();
  }

  void configure(MonitorSettings value) {
    _generation++;
    _service.cancel();
    _pollTimer?.cancel();
    settings = value;
    reading = null;
    lastSuccess = null;
    error = null;
    _failures = 0;
    retry();
  }

  void retry() {
    if (!_active || _disposed) return;
    _pollTimer?.cancel();
    link = LinkState.connecting;
    error = null;
    notifyListeners();
    if (!_busy) unawaited(_poll());
  }

  void _accept(DistanceReading value) {
    reading = value;
    lastSuccess = value.receivedAt;
    error = null;
    _failures = 0;
    link = LinkState.connected;
    notifyListeners();
  }

  Future<void> _poll() async {
    if (_busy || !_active || _disposed) return;
    _busy = true;
    final generation = _generation;
    try {
      final result = await _service.read(settings);
      if (!_disposed && _active && generation == _generation) _accept(result);
    } catch (e) {
      if (!_disposed && _active && generation == _generation) {
        reading = null;
        _failures++;
        link = LinkState.disconnected;
        error = e is FormatException
            ? e.message
            : 'Cannot reach ESP32. Check address, power, and WiFi.';
        notifyListeners();
      }
    } finally {
      _busy = false;
      if (_active && !_disposed) {
        final delay = generation != _generation
            ? 0
            : min(10000, settings.intervalMs * (1 << min(_failures, 4)));
        _pollTimer = Timer(Duration(milliseconds: delay), _poll);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _generation++;
    _pollTimer?.cancel();
    _ageTimer?.cancel();
    _service.cancel();
    ageTick.dispose();
    super.dispose();
  }
}
