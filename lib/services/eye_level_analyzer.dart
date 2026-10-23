import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum EyeAlignmentQuality {
  perfect,
  slightTilt,
  badTilt,
}

class EyeLevelAnalyzer {
  EyeAlignmentQuality quality =
      EyeAlignmentQuality.perfect;

  void analyze(Face face) {
    final leftEye =
        face.landmarks[FaceLandmarkType.leftEye];
    final rightEye =
        face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return;

    final dy =
        (leftEye.position.y - rightEye.position.y)
            .abs();

    if (dy < 6) {
      quality = EyeAlignmentQuality.perfect;
    } else if (dy < 15) {
      quality = EyeAlignmentQuality.slightTilt;
    } else {
      quality = EyeAlignmentQuality.badTilt;
    }
  }
}