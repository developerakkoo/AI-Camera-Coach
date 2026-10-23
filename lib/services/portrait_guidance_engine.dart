import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PortraitGuidanceEngine {
  String generateFeedback(Face face, Size screenSize) {
    final centerX = face.boundingBox.center.dx;
    final centerY = face.boundingBox.center.dy;

    final leftThird = screenSize.width / 3;
    final rightThird = 2 * screenSize.width / 3;

    if (centerX < leftThird) return "Move slightly right";
    if (centerX > rightThird) return "Move slightly left";
    if (centerY < screenSize.height * 0.3) return "Lower camera slightly";
    if (centerY > screenSize.height * 0.7) return "Raise camera slightly";

    if ((face.smilingProbability ?? 0) < 0.3)
      return "Try a natural smile 😊";

    return "Perfect framing 🔥";
  }

  int calculateScore(Face face, Size screenSize) {
    final centerX = face.boundingBox.center.dx;
    final idealX = screenSize.width / 2;
    final difference = (centerX - idealX).abs();
    final normalized = difference / idealX;
    final score = 100 - (normalized * 100);
    return score.clamp(0, 100).toInt();
  }
}