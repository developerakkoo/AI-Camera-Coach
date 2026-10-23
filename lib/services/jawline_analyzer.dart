import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum JawlineQuality {
  perfect,
  adjustUp,
  adjustDown,
}

class JawlineAnalyzer {
  JawlineQuality quality = JawlineQuality.perfect;
  String feedback = "";

  void analyze(Face face) {
    double? headX = face.headEulerAngleX;

    if (headX == null) {
      quality = JawlineQuality.perfect;
      feedback = "";
      return;
    }

    if (headX > 18) {
      quality = JawlineQuality.adjustUp; // camera too low
      feedback = "Raise phone for better jawline";
    } else if (headX < -12) {
      quality = JawlineQuality.adjustDown; // camera too high
      feedback = "Lower phone slightly";
    } else {
      quality = JawlineQuality.perfect;
      feedback = "";
    }
  }
}