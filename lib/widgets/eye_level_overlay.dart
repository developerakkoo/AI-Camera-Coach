import 'package:flutter/material.dart';
import '../services/eye_level_analyzer.dart';

class EyeLevelOverlay extends StatelessWidget {
  final EyeAlignmentQuality quality;

  const EyeLevelOverlay({super.key, required this.quality});

  Color getColor() {
    switch (quality) {
      case EyeAlignmentQuality.perfect:
        return Colors.greenAccent;
      case EyeAlignmentQuality.slightTilt:
        return Colors.orangeAccent;
      case EyeAlignmentQuality.badTilt:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _EyeLinePainter(getColor()),
        ),
      ),
    );
  }
}

class _EyeLinePainter extends CustomPainter {
  final Color color;

  _EyeLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height * 0.4;

    canvas.drawLine(
      Offset(size.width * 0.2, centerY),
      Offset(size.width * 0.8, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) =>
      true;
}