import 'package:flutter/material.dart';
import '../app/app.dart';
import '../controllers/distance_controller.dart';
import '../models/distance_reading.dart';

extension StatusPresentation on DistanceStatus {
  String get label => switch (this) {
    DistanceStatus.safe => 'SAFE',
    DistanceStatus.caution => 'CAUTION',
    DistanceStatus.danger => 'DANGER',
    DistanceStatus.noData => 'NO DATA',
  };
  Color get color => switch (this) {
    DistanceStatus.safe => const Color(0xFF16A34A),
    DistanceStatus.caution => const Color(0xFFFACC15),
    DistanceStatus.danger => const Color(0xFFDC2626),
    DistanceStatus.noData => const Color(0xFF94A3B8),
  };
  Color get ink => this == DistanceStatus.caution
      ? const Color(0xFF815000)
      : this == DistanceStatus.noData
      ? secondaryText
      : color;
  String get range => switch (this) {
    DistanceStatus.safe => 'More than 30 cm',
    DistanceStatus.caution => '15 to 30 cm',
    DistanceStatus.danger => 'Less than 15 cm',
    DistanceStatus.noData => 'Waiting for a valid sensor reading',
  };
  IconData get icon => switch (this) {
    DistanceStatus.safe => Icons.check_circle_outline,
    DistanceStatus.caution => Icons.warning_amber_rounded,
    DistanceStatus.danger => Icons.error_outline,
    DistanceStatus.noData => Icons.sensors_off,
  };
}

Duration motionDuration(BuildContext context, bool enabled) =>
    enabled && !MediaQuery.disableAnimationsOf(context)
    ? const Duration(milliseconds: 350)
    : Duration.zero;

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 18});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080B2345),
          blurRadius: 20,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class AdaptiveItems extends StatelessWidget {
  const AdaptiveItems({super.key, required this.children, this.minWidth = 155});
  final List<Widget> children;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final horizontal =
          constraints.maxWidth >=
          children.length * minWidth * scale + (children.length - 1) * 10;
      if (!horizontal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.controller});
  final DistanceController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (title, badge, color, icon) = switch (c.link) {
      LinkState.connected => (
        'ESP32 Connected',
        'Online',
        const Color(0xFF16A34A),
        Icons.wifi,
      ),
      LinkState.connecting => (
        'Connecting to ESP32',
        'Connecting',
        const Color(0xFF2563EB),
        Icons.wifi_find,
      ),
      LinkState.paused => (
        'Monitoring paused',
        'Paused',
        secondaryText,
        Icons.pause_circle_outline,
      ),
      LinkState.disconnected => (
        'ESP32 Disconnected',
        'Offline',
        secondaryText,
        Icons.wifi_off,
      ),
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                foregroundColor: color,
                radius: 25,
                child: Icon(icon, size: 29),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host: ${c.settings.host}:${c.settings.port}',
                      style: const TextStyle(color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: motionDuration(context, c.settings.animations),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '●  $badge',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (c.error != null) ...[
            const SizedBox(height: 10),
            Text(c.error!, style: const TextStyle(color: secondaryText)),
          ],
          if (c.link == LinkState.disconnected)
            TextButton.icon(
              onPressed: c.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.status, required this.animations});
  final DistanceStatus status;
  final bool animations;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: motionDuration(context, animations),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Icon(status.icon, color: status.ink, size: 38),
        const SizedBox(width: 14),
        Expanded(
          child: AnimatedSwitcher(
            duration: motionDuration(context, animations),
            child: Column(
              key: ValueKey(status),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    color: status.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                Text(
                  status == DistanceStatus.noData
                      ? status.range
                      : 'Object is ${status.range.toLowerCase()} away',
                  style: TextStyle(color: status.ink),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class DistanceGuide extends StatelessWidget {
  const DistanceGuide({super.key, required this.active});
  final DistanceStatus active;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distance Guide',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
        ),
        const Text('Distance ranges', style: TextStyle(color: secondaryText)),
        const SizedBox(height: 16),
        AdaptiveItems(
          minWidth: 100,
          children: [
            for (final s in [
              DistanceStatus.safe,
              DistanceStatus.caution,
              DistanceStatus.danger,
            ])
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: active == s ? s.color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, color: s.color, size: 19),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            color: s.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(s.range),
                        const SizedBox(height: 4),
                        Text(
                          '${s == DistanceStatus.safe
                              ? 'Green'
                              : s == DistanceStatus.caution
                              ? 'Yellow'
                              : 'Red'} LED',
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class LiveDataCard extends StatelessWidget {
  const LiveDataCard({super.key, required this.controller});
  final DistanceController controller;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Data',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
        ),
        const SizedBox(height: 18),
        AdaptiveItems(
          minWidth: 100,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: controller.ageTick,
              builder: (_, value, child) =>
                  _item(Icons.schedule, 'Last update', controller.ageLabel),
            ),
            _item(Icons.wifi, 'Connection', switch (controller.link) {
              LinkState.connected => 'Active',
              LinkState.connecting => 'Connecting',
              LinkState.paused => 'Paused',
              LinkState.disconnected => 'Offline',
            }),
            _item(
              Icons.sensors,
              'Sensor status',
              controller.distance != null
                  ? 'Reading'
                  : controller.error?.contains('Sensor') == true
                  ? 'Sensor Error'
                  : 'No Data',
            ),
          ],
        ),
      ],
    ),
  );
  Widget _item(IconData icon, String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFEAF1FF),
        child: Icon(icon, color: const Color(0xFF2563EB)),
      ),
      const SizedBox(height: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: secondaryText, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ],
  );
}
