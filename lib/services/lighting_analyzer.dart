import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/input_image_from_camera_image.dart';

enum LightingQuality {
  good,
  okay,
  poor,
}

class LightingAnalyzer {
  String feedback = "";
  int lightingScore = 0;
  LightingQuality quality = LightingQuality.good;

  /// Raw average luminance of the face region, 0–255. Used by AutoCameraController.
  double faceBrightness = 128.0;
  /// Average luminance of the background region, 0–255.
  double backgroundBrightness = 128.0;

  String _lastFeedback = "";
  int _stableCount = 0;

  void analyze(CameraImage image, Face face) {
    final int width = image.width;
    final int height = image.height;

    final Rect faceRect = face.boundingBox;

    int startX = faceRect.left.clamp(0, width - 1).toInt();
    int endX = faceRect.right.clamp(0, width - 1).toInt();
    int startY = faceRect.top.clamp(0, height - 1).toInt();
    int endY = faceRect.bottom.clamp(0, height - 1).toInt();

    int midX = ((startX + endX) / 2).toInt();

    double leftBrightness = 0;
    double rightBrightness = 0;

    int leftPixels = 0;
    int rightPixels = 0;

    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        final brightness =
            CameraImageLuminance.sample(image, x, y, width, height);

        if (x < midX) {
          leftBrightness += brightness;
          leftPixels++;
        } else {
          rightBrightness += brightness;
          rightPixels++;
        }
      }
    }

    if (leftPixels == 0 || rightPixels == 0) return;

    leftBrightness /= leftPixels;
    rightBrightness /= rightPixels;
    faceBrightness = (leftBrightness + rightBrightness) / 2.0;

    // Sample background brightness (corners, outside face rect)
    double bgTotal = 0;
    int bgCount = 0;
    for (int y = 0; y < height; y += 8) {
      for (int x = 0; x < width; x += 8) {
        if (x >= startX && x <= endX && y >= startY && y <= endY) continue;
        bgTotal += CameraImageLuminance.sample(image, x, y, width, height);
        bgCount++;
      }
    }
    if (bgCount > 0) backgroundBrightness = bgTotal / bgCount;

    _evaluateLighting(leftBrightness, rightBrightness, face);
  }

  void _evaluateLighting(double left, double right, Face face) {
  double diff = (left - right).abs();
  bool leftBrighter = left > right;

  double? headY = face.headEulerAngleY; // left/right rotation

  String newFeedback = "";
  int newScore = 0;
  LightingQuality newQuality = LightingQuality.good;

  if (left < 60 && right < 60) {
    newFeedback = "Move near window for better light";
    newScore = 30;
    newQuality = LightingQuality.poor;
  } 
  else if (diff < 18) {
    newFeedback = "";
    newScore = 85;
    newQuality = LightingQuality.good;
  } 
  else if (diff < 45) {
    // 💡 Light Direction + Head Alignment Logic

    if (leftBrighter) {
      if (headY != null && headY < -8) {
        newFeedback = "Good alignment with light 🔥";
        newScore = 95;
        newQuality = LightingQuality.good;
      } else {
        newFeedback = "Turn slightly toward left light";
        newScore = 85;
        newQuality = LightingQuality.okay;
      }
    } else {
      if (headY != null && headY > 8) {
        newFeedback = "Good alignment with light 🔥";
        newScore = 95;
        newQuality = LightingQuality.good;
      } else {
        newFeedback = "Turn slightly toward right light";
        newScore = 85;
        newQuality = LightingQuality.okay;
      }
    }
  } 
  else {
    newFeedback = "Harsh lighting — soften shadows";
    newScore = 50;
    newQuality = LightingQuality.poor;
  }

  // Stability logic (keep same as before)
  if (newFeedback == _lastFeedback) {
    _stableCount++;
  } else {
    _stableCount = 0;
  }

  if (_stableCount > 5) {
    feedback = newFeedback;
    lightingScore = newScore;
    quality = newQuality;
  }

  _lastFeedback = newFeedback;
}
}