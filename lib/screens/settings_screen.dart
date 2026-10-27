import 'package:flutter/material.dart';
import '../controllers/distance_controller.dart';
import '../models/monitor_settings.dart';
import '../services/esp32_service.dart';
import '../services/settings_service.dart';
import '../widgets/dashboard_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.store,
  });
  final DistanceController controller;
  final SettingsService store;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _host, _port, _interval, _maximum;
  late bool _animations;
  bool _busy = false;
  String? _message;
  final _tester = Esp32Service();
  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _host = TextEditingController(text: s.host);
    _port = TextEditingController(text: '${s.port}');
    _interval = TextEditingController(text: '${s.intervalMs}');
    _maximum = TextEditingController(text: s.gaugeMax.toStringAsFixed(0));
    _animations = s.animations;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _interval.dispose();
    _maximum.dispose();
    _tester.cancel();
    super.dispose();
  }

  MonitorSettings _settings() => MonitorSettings(
    host: _host.text.trim(),
    port: int.parse(_port.text),
    intervalMs: int.parse(_interval.text),
    gaugeMax: double.parse(_maximum.text),
    animations: _animations,
  );
  Future<void> _submit(bool test) async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = test ? 'Testing ESP32…' : 'Saving…';
    });
    try {
      final settings = _settings();
      if (test) {
        final reading = await _tester.read(settings);
        if (mounted) {
          setState(
            () => _message =
                'ESP32 responded: ${reading.distance.toStringAsFixed(1)} cm',
          );
        }
      } else {
        await widget.store.save(settings);
        if (!mounted) return;
        widget.controller.configure(settings);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = test
              ? 'Connection failed. Check the address, WiFi, firmware, and Android HTTP allowlist.'
              : 'Settings could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _number(String? value, int min, int max) {
    final number = int.tryParse(value ?? '');
    return number == null || number < min || number > max
        ? 'Enter a whole number from $min to $max'
        : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ESP32 connection',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _host,
                          decoration: const InputDecoration(
                            labelText: 'IP address or hostname',
                            helperText: 'Example: esp32.local or 192.168.1.50',
                          ),
                          validator: MonitorSettings.validateHost,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _port,
                          decoration: const InputDecoration(labelText: 'Port'),
                          keyboardType: TextInputType.number,
                          validator: (v) => _number(v, 1, 65535),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Phone and ESP32 must share a WiFi network. The endpoint is /distance.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Android release builds allow HTTP to esp32.local and 192.168.1.50. For another host, update the Android network security allowlist and rebuild.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _submit(true),
                          icon: const Icon(Icons.wifi_find),
                          label: const Text('Test connection'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Monitoring',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _interval,
                          decoration: const InputDecoration(
                            labelText: 'Polling interval (ms)',
                            helperText: '250–10000 ms; default 500',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _number(v, 250, 10000),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _maximum,
                          decoration: const InputDecoration(
                            labelText: 'Gauge maximum (cm)',
                            helperText:
                                'Visual scale only; readings are never capped',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _number(v, 30, 1000),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Animations'),
                          subtitle: const Text(
                            'Also respects reduced motion settings',
                          ),
                          value: _animations,
                          onChanged: (v) => setState(() => _animations = v),
                        ),
                        const Text(
                          'Fixed thresholds: DANGER <15 cm, CAUTION 15–30 cm, SAFE >30 cm.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _submit(false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Save configuration'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
