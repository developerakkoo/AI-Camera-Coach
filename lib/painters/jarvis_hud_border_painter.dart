import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';

class JarvisHudBorderPainter extends CustomPainter {
  const JarvisHudBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 6.0;
    const cLen = 36.0;

    final bracketPaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final bracketGlow = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final p in [bracketGlow, bracketPaint]) {
      // TL
      canvas.drawLine(Offset(inset, inset + cLen), Offset(inset, inset), p);
      canvas.drawLine(Offset(inset, inset), Offset(inset + cLen, inset), p);
      // TR
      canvas.drawLine(
          Offset(size.width - inset - cLen, inset), Offset(size.width - inset, inset), p);
      canvas.drawLine(Offset(size.width - inset, inset),
          Offset(size.width - inset, inset + cLen), p);
      // BL
      canvas.drawLine(Offset(inset, size.height - inset - cLen),
          Offset(inset, size.height - inset), p);
      canvas.drawLine(Offset(inset, size.height - inset),
          Offset(inset + cLen, size.height - inset), p);
      // BR
      canvas.drawLine(Offset(size.width - inset - cLen, size.height - inset),
          Offset(size.width - inset, size.height - inset), p);
      canvas.drawLine(Offset(size.width - inset, size.height - inset),
          Offset(size.width - inset, size.height - inset - cLen), p);
    }

    _drawEdgeTicks(canvas, size, inset, cLen);
  }

  void _drawEdgeTicks(Canvas canvas, Size size, double inset, double cLen) {
    final tickPaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final start = inset + cLen + 8;
    const spacing = 16.0;

    // Top edge
    for (double x = start; x < size.width - cLen - inset; x += spacing) {
      final h = (x % (spacing * 4) < 1) ? 9.0 : 4.5;
      canvas.drawLine(Offset(x, inset), Offset(x, inset + h), tickPaint);
    }

    // Bottom edge
    for (double x = start; x < size.width - cLen - inset; x += spacing) {
      final h = (x % (spacing * 4) < 1) ? 9.0 : 4.5;
      canvas.drawLine(Offset(x, size.height - inset),
          Offset(x, size.height - inset - h), tickPaint);
    }

    // Left edge
    for (double y = start; y < size.height - cLen - inset; y += spacing) {
      final w = (y % (spacing * 4) < 1) ? 9.0 : 4.5;
      canvas.drawLine(Offset(inset, y), Offset(inset + w, y), tickPaint);
    }

    // Right edge
    for (double y = start; y < size.height - cLen - inset; y += spacing) {
      final w = (y % (spacing * 4) < 1) ? 9.0 : 4.5;
      canvas.drawLine(Offset(size.width - inset, y),
          Offset(size.width - inset - w, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(JarvisHudBorderPainter old) => false;
}
