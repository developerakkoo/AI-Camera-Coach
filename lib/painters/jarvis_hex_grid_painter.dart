import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';

class JarvisHexGridPainter extends CustomPainter {
  final double opacity;

  const JarvisHexGridPainter({this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const r = 20.0;
    final w = r * 2;
    final h = r * sqrt(3);

    int col = 0;
    for (double x = -r; x < size.width + r; x += w * 0.75) {
      final yOff = col.isOdd ? h / 2 : 0.0;
      for (double y = -h + yOff; y < size.height + h; y += h) {
        _drawHex(canvas, Offset(x, y), r, paint);
      }
      col++;
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 180 * (60 * i - 30);
      final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(JarvisHexGridPainter old) => old.opacity != opacity;
}
