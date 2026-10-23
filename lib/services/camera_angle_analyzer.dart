import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum AngleQuality {
  good,
  adjust,
}

class CameraAngleAnalyzer {
  AngleQuality quality = AngleQuality.good;
  String feedback = "";

  String _lastFeedback = "";
  int _stableCount = 0;

  void analyze(Face face) {
    String newFeedback = "";
    AngleQuality newQuality = AngleQuality.good;

    double? headX = face.headEulerAngleX; // up/down
    double? headZ = face.headEulerAngleZ; // tilt

    // 🔻 Camera too low (chin heavy)
    if (headX != null && headX > 15) {
      newFeedback = "Raise camera slightly";
      newQuality = AngleQuality.adjust;
    }
    // 🔺 Camera too high
    else if (headX != null && headX < -15) {
      newFeedback = "Lower camera slightly";
      newQuality = AngleQuality.adjust;
    }
    // ↗ Head tilted
    else if (headZ != null && headZ.abs() > 12) {
      newFeedback = "Keep head straight for clean portrait";
      newQuality = AngleQuality.adjust;
    }
    else {
      newFeedback = "";
      newQuality = AngleQuality.good;
    }

    // Stability
    if (newFeedback == _lastFeedback) {
      _stableCount++;
    } else {
      _stableCount = 0;
    }

    if (_stableCount > 5) {
      feedback = newFeedback;
      quality = newQuality;
    }

    _lastFeedback = newFeedback;
  }
}