import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/monitor_settings.dart';

class SettingsService {
  Future<MonitorSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('monitor_settings');
      if (raw == null) return const MonitorSettings();
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final s = MonitorSettings(
        host: d['host'] as String,
        port: d['port'] as int,
        intervalMs: d['interval'] as int,
        animations: d['animations'] as bool,
        gaugeMax: (d['gaugeMax'] as num).toDouble(),
      );
      if (MonitorSettings.validateHost(s.host) != null ||
          s.port < 1 ||
          s.port > 65535 ||
          s.intervalMs < 250 ||
          s.intervalMs > 10000 ||
          !s.gaugeMax.isFinite ||
          s.gaugeMax < 30 ||
          s.gaugeMax > 1000) {
        return const MonitorSettings();
      }
      return s;
    } catch (_) {
      return const MonitorSettings();
    }
  }

  Future<void> save(MonitorSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'monitor_settings',
      jsonEncode({
        'host': s.host,
        'port': s.port,
        'interval': s.intervalMs,
        'animations': s.animations,
        'gaugeMax': s.gaugeMax,
      }),
    )) {
      throw StateError('Could not save settings');
    }
  }
}
