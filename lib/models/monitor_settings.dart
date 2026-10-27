class MonitorSettings {
  const MonitorSettings({
    this.host = 'esp32.local',
    this.port = 80,
    this.intervalMs = 500,
    this.animations = true,
    this.gaugeMax = 100,
  });
  final String host;
  final int port, intervalMs;
  final bool animations;
  final double gaugeMax;
  Uri get endpoint =>
      Uri(scheme: 'http', host: host, port: port, path: '/distance');
  static String? validateHost(String? input) {
    final host = input?.trim() ?? '';
    if (host.isEmpty) return 'Enter an IPv4 address or local hostname';
    if (RegExp(r'^[0-9.]+$').hasMatch(host)) {
      final parts = host.split('.');
      if (parts.length != 4 ||
          parts.any(
            (p) =>
                int.tryParse(p) == null || int.parse(p) > 255 || p.length > 3,
          )) {
        return 'Enter a valid IPv4 address';
      }
      return null;
    }
    if (host.length > 253 ||
        !host
            .split('.')
            .every(
              (p) => RegExp(
                r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
              ).hasMatch(p),
            )) {
      return 'Use a hostname only, without http:// or a path';
    }
    return null;
  }
}
