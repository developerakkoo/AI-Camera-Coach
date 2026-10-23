import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../theme/jarvis_colors.dart';

class JarvisFaceFramePainter extends CustomPainter {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;
  final double scanProgress;
  final int score;

  const JarvisFaceFramePainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.scanProgress,
    required this.score,
  });

  Color get _frameColor {
    if (score >= 80) return JarvisColors.good;
    if (score >= 50) return JarvisColors.warning;
    return JarvisColors.primary;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final face = faces.first;
    final rect = face.boundingBox;
    final scaleX = screenSize.width / previewSize.width;
    final scaleY = screenSize.height / previewSize.height;

    final raw = Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
    final pad = raw.width * 0.10;
    final fr = raw.inflate(pad);

    _drawCornerBrackets(canvas, fr);
    _drawScanLine(canvas, fr);
    _drawCrosshair(canvas, fr);
    _drawDataTicks(canvas, fr);
  }

  void _drawCornerBrackets(Canvas canvas, Rect r) {
    final color = _frameColor;
    final cLen = r.width * 0.20;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..strokeCap = StrokeCap.square;

    final mainPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final p in [glowPaint, mainPaint]) {
      // TL
      canvas.drawLine(r.topLeft, r.topLeft + Offset(cLen, 0), p);
      canvas.drawLine(r.topLeft, r.topLeft + Offset(0, cLen), p);
      // TR
      canvas.drawLine(r.topRight, r.topRight - Offset(cLen, 0), p);
      canvas.drawLine(r.topRight, r.topRight + Offset(0, cLen), p);
      // BL
      canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(cLen, 0), p);
      canvas.drawLine(r.bottomLeft, r.bottomLeft - Offset(0, cLen), p);
      // BR
      canvas.drawLine(r.bottomRight, r.bottomRight - Offset(cLen, 0), p);
      canvas.drawLine(r.bottomRight, r.bottomRight - Offset(0, cLen), p);
    }

    // Inner offset lines (secondary bracket)
    const inset = 6.0;
    final iLen = cLen * 0.4;
    final ir = r.deflate(inset);
    for (final p in [innerPaint]) {
      canvas.drawLine(ir.topLeft, ir.topLeft + Offset(iLen, 0), p);
      canvas.drawLine(ir.topLeft, ir.topLeft + Offset(0, iLen), p);
      canvas.drawLine(ir.topRight, ir.topRight - Offset(iLen, 0), p);
      canvas.drawLine(ir.topRight, ir.topRight + Offset(0, iLen), p);
      canvas.drawLine(ir.bottomLeft, ir.bottomLeft + Offset(iLen, 0), p);
      canvas.drawLine(ir.bottomLeft, ir.bottomLeft - Offset(0, iLen), p);
      canvas.drawLine(ir.bottomRight, ir.bottomRight - Offset(iLen, 0), p);
      canvas.drawLine(ir.bottomRight, ir.bottomRight - Offset(0, iLen), p);
    }

    // Corner dots
    final dotGlow = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(corner, 4, dotGlow);
      canvas.drawCircle(corner, 2, dot);
    }
  }

  void _drawScanLine(Canvas canvas, Rect r) {
    final y = r.top + r.height * scanProgress;

    // Horizontal sweep line
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          JarvisColors.primary.withValues(alpha: 0.9),
          JarvisColors.primary,
          JarvisColors.primary.withValues(alpha: 0.9),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(r.left, y, r.width, 1.5))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(r.left, y), Offset(r.right, y), linePaint);

    // Scan trail (gradient fill behind the line)
    if (scanProgress > 0.02) {
      final trailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            JarvisColors.primary.withValues(alpha: 0.0),
            JarvisColors.primary.withValues(alpha: 0.06),
          ],
        ).createShader(Rect.fromLTWH(r.left, r.top, r.width, y - r.top))
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(r.left, r.top, r.right, y),
        trailPaint,
      );
    }

    // Bright dot on scan line ends
    final dotPaint = Paint()
      ..color = JarvisColors.primary
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(r.left, y), 3, dotPaint);
    canvas.drawCircle(Offset(r.right, y), 3, dotPaint);
  }

  void _drawCrosshair(Canvas canvas, Rect r) {
    final center = r.center;
    const len = 10.0;
    const gap = 4.0;

    final paint = Paint()
      ..color = _frameColor.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(center.dx - len - gap, center.dy),
        Offset(center.dx - gap, center.dy), paint);
    canvas.drawLine(Offset(center.dx + gap, center.dy),
        Offset(center.dx + len + gap, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - len - gap),
        Offset(center.dx, center.dy - gap), paint);
    canvas.drawLine(Offset(center.dx, center.dy + gap),
        Offset(center.dx, center.dy + len + gap), paint);

    final dotGlow = Paint()
      ..color = _frameColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, 3, dotGlow);
    final dotSolid = Paint()
      ..color = _frameColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, dotSolid);
  }

  void _drawDataTicks(Canvas canvas, Rect r) {
    final tickPaint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Right edge ticks (every 10% of height)
    for (int i = 1; i < 10; i++) {
      final y = r.top + r.height * (i / 10.0);
      final tickLen = i % 5 == 0 ? 8.0 : 4.0;
      canvas.drawLine(
          Offset(r.right, y), Offset(r.right + tickLen, y), tickPaint);
    }

    // Bottom edge ticks
    for (int i = 1; i < 10; i++) {
      final x = r.left + r.width * (i / 10.0);
      final tickLen = i % 5 == 0 ? 8.0 : 4.0;
      canvas.drawLine(
          Offset(x, r.bottom), Offset(x, r.bottom + tickLen), tickPaint);
    }
  }

  @override
  bool shouldRepaint(JarvisFaceFramePainter old) =>
      old.scanProgress != scanProgress ||
      old.score != score ||
      old.faces.length != faces.length;
}
