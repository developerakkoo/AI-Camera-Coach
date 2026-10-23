import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';

class JarvisArcPainter extends CustomPainter {
  final double progress;
  final Color? arcColor;
  final double strokeWidth;
  final double startAngleDeg;
  final double sweepDeg;
  final bool showTicks;

  const JarvisArcPainter({
    required this.progress,
    this.arcColor,
    this.strokeWidth = 4,
    this.startAngleDeg = 135,
    this.sweepDeg = 270,
    this.showTicks = true,
  });

  Color get _color {
    if (arcColor != null) return arcColor!;
    if (progress >= 0.8) return JarvisColors.good;
    if (progress >= 0.5) return JarvisColors.warning;
    return JarvisColors.critical;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - strokeWidth;

    final startRad = startAngleDeg * pi / 180;
    final sweepRad = sweepDeg * pi / 180;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = JarvisColors.border.withValues(alpha: 0.5)
        ..strokeWidth = strokeWidth * 0.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (showTicks) {
      _drawTicks(canvas, center, radius, startRad, sweepRad);
    }

    if (progress <= 0.001) return;

    final filled = sweepRad * progress.clamp(0.0, 1.0);
    final color = _color;

    // Glow layer
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      filled,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = strokeWidth + 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      filled,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // End-cap glow dot
    final endAngleRad = startRad + filled;
    final endPt = Offset(
      center.dx + radius * cos(endAngleRad),
      center.dy + radius * sin(endAngleRad),
    );
    canvas.drawCircle(
      endPt,
      strokeWidth + 2,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      endPt,
      strokeWidth / 2,
      Paint()..color = color,
    );
  }

  void _drawTicks(
      Canvas canvas, Offset center, double radius, double startRad, double sweepRad) {
    const tickCount = 20;
    final outerR = radius + strokeWidth + 2;
    final tickPaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = startRad + sweepRad * t;
      final isMajor = i % 5 == 0;
      final innerR = outerR - (isMajor ? 6.0 : 3.0);

      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle), center.dy + innerR * sin(angle)),
        Offset(center.dx + outerR * cos(angle), center.dy + outerR * sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(JarvisArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
