import 'dart:math';
import 'package:flutter/material.dart';
import '../app/app.dart';
import '../models/distance_reading.dart';
import 'dashboard_components.dart';

class DistanceGauge extends StatelessWidget {
  const DistanceGauge({
    super.key,
    required this.distance,
    required this.status,
    required this.maximum,
    required this.animations,
  });
  final double? distance;
  final DistanceStatus status;
  final double maximum;
  final bool animations;
  @override
  Widget build(BuildContext context) {
    final progress = ((distance ?? 0) / maximum).clamp(0.0, 1.0);
    return Semantics(
      label: distance == null
          ? 'No distance data'
          : '${distance!.toStringAsFixed(1)} centimeters. ${status.label}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = min(constraints.maxWidth, 380.0);
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final text = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Distance',
                  style: TextStyle(color: secondaryText, fontSize: 18),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    distance?.toStringAsFixed(1) ?? '—',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 64,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const Text(
                  'cm',
                  style: TextStyle(color: secondaryText, fontSize: 22),
                ),
              ],
            );
            final gauge = SizedBox(
              width: size,
              height: size * .86,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: motionDuration(context, animations),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) =>
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: status.color),
                      duration: motionDuration(context, animations),
                      builder: (context, color, child) => RepaintBoundary(
                        child: CustomPaint(
                          painter: _GaugePainter(value, color ?? status.color),
                          child: child,
                        ),
                      ),
                      child: scale <= 1.4
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  size * .19,
                                  20,
                                  size * .19,
                                  0,
                                ),
                                child: text,
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
              ),
            );
            return Column(
              children: [
                gauge,
                if (scale > 1.4) text,
                Text(
                  'Arc scale 0–${maximum.toStringAsFixed(0)} cm',
                  style: const TextStyle(color: secondaryText, fontSize: 12),
                ),
                if (distance != null && distance! > maximum)
                  const Text(
                    'Reading exceeds arc scale',
                    style: TextStyle(color: secondaryText),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * .41;
    final center = Offset(size.width / 2, size.width * .46);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = size.width * .052;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = 3 * pi / 4;
    const sweep = 3 * pi / 2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      paint..color = const Color(0xFFE2E8F0),
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        start,
        sweep * progress,
        false,
        paint..color = color,
      );
    }
    if (progress > 0) {
      final angle = start + sweep * progress;
      final point = center + Offset(cos(angle) * radius, sin(angle) * radius);
      canvas.drawCircle(point, stroke * .72, Paint()..color = Colors.white);
      canvas.drawCircle(point, stroke * .48, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
