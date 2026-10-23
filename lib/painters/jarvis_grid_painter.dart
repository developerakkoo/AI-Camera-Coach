import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';

class JarvisGridPainter extends CustomPainter {
  const JarvisGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.30)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final w = size.width;
    final h = size.height;

    // ── Two vertical lines at 1/3 and 2/3 ──────────────────────────────────
    for (final x in [w / 3, 2 * w / 3]) {
      for (final p in [glowPaint, linePaint]) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), p);
      }
    }

    // ── Two horizontal lines at 1/3 and 2/3 ────────────────────────────────
    for (final y in [h / 3, 2 * h / 3]) {
      for (final p in [glowPaint, linePaint]) {
        canvas.drawLine(Offset(0, y), Offset(w, y), p);
      }
    }

    // ── Power-point intersection dots ───────────────────────────────────────
    final dotGlow = Paint()
      ..color = JarvisColors.gold.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final dot = Paint()..color = JarvisColors.gold;

    for (final x in [w / 3, 2 * w / 3]) {
      for (final y in [h / 3, 2 * h / 3]) {
        canvas.drawCircle(Offset(x, y), 5, dotGlow);
        canvas.drawCircle(Offset(x, y), 2, dot);
      }
    }

    // ── Corner tick labels (tiny "1/3" markers) ──────────────────────────────
    _drawTick(canvas, Offset(w / 3, 0), Offset(w / 3, 5), linePaint);
    _drawTick(canvas, Offset(2 * w / 3, 0), Offset(2 * w / 3, 5), linePaint);
    _drawTick(canvas, Offset(0, h / 3), Offset(5, h / 3), linePaint);
    _drawTick(canvas, Offset(0, 2 * h / 3), Offset(5, 2 * h / 3), linePaint);
  }

  void _drawTick(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(a, b,
        paint..strokeWidth = 2..color = JarvisColors.gold.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(JarvisGridPainter old) => false;
}
