import 'package:flutter/material.dart';
import '../services/eye_level_analyzer.dart';
import '../theme/jarvis_colors.dart';

class JarvisEyeLine extends StatelessWidget {
  final EyeAlignmentQuality quality;

  const JarvisEyeLine({super.key, required this.quality});

  Color get _color {
    switch (quality) {
      case EyeAlignmentQuality.perfect:
        return JarvisColors.good;
      case EyeAlignmentQuality.slightTilt:
        return JarvisColors.warning;
      case EyeAlignmentQuality.badTilt:
        return JarvisColors.critical;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _EyeLinePainter(_color),
        ),
      ),
    );
  }
}

class _EyeLinePainter extends CustomPainter {
  final Color color;

  const _EyeLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.4;
    final xStart = size.width * 0.08;
    final xEnd = size.width * 0.92;

    // Glow
    canvas.drawLine(
      Offset(xStart, y),
      Offset(xEnd, y),
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Dashed line
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashLen = 12.0;
    const gapLen = 6.0;
    double x = xStart;
    while (x < xEnd) {
      final end = (x + dashLen).clamp(xStart, xEnd);
      canvas.drawLine(Offset(x, y), Offset(end, y), dashPaint);
      x += dashLen + gapLen;
    }

    // End markers
    final markerPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const mLen = 8.0;
    for (final mx in [xStart, xEnd]) {
      canvas.drawLine(Offset(mx, y - mLen / 2), Offset(mx, y + mLen / 2), markerPaint);
    }

    // Center diamond
    final centerX = size.width / 2;
    final diamondPath = Path()
      ..moveTo(centerX, y - 5)
      ..lineTo(centerX + 4, y)
      ..lineTo(centerX, y + 5)
      ..lineTo(centerX - 4, y)
      ..close();

    canvas.drawPath(
      diamondPath,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_EyeLinePainter old) => old.color != color;
}
