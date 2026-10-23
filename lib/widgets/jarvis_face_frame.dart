import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../painters/jarvis_face_frame_painter.dart';

class JarvisFaceFrame extends StatefulWidget {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;
  final int score;

  const JarvisFaceFrame({
    super.key,
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.score,
  });

  @override
  State<JarvisFaceFrame> createState() => _JarvisFaceFrameState();
}

class _JarvisFaceFrameState extends State<JarvisFaceFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanCtrl,
      builder: (_, __) => CustomPaint(
        painter: JarvisFaceFramePainter(
          faces: widget.faces,
          previewSize: widget.previewSize,
          screenSize: widget.screenSize,
          scanProgress: _scanCtrl.value,
          score: widget.score,
        ),
      ),
    );
  }
}
