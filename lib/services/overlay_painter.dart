import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;

  FaceOverlayPainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final face = faces.first;
    final rect = face.boundingBox;

    final scaleX = screenSize.width / previewSize.width;
    final scaleY = screenSize.height / previewSize.height;

    final transformedRect = Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );

    _drawAppleStyleFrame(canvas, transformedRect);
  }

  void _drawAppleStyleFrame(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const corner = 22.0;

    // Top Left
    canvas.drawLine(rect.topLeft,
        rect.topLeft + const Offset(corner, 0), paint);
    canvas.drawLine(rect.topLeft,
        rect.topLeft + const Offset(0, corner), paint);

    // Top Right
    canvas.drawLine(rect.topRight,
        rect.topRight - const Offset(corner, 0), paint);
    canvas.drawLine(rect.topRight,
        rect.topRight + const Offset(0, corner), paint);

    // Bottom Left
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft + const Offset(corner, 0), paint);
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft - const Offset(0, corner), paint);

    // Bottom Right
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight - const Offset(corner, 0), paint);
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight - const Offset(0, corner), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}