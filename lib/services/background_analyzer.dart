import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/input_image_from_camera_image.dart';

enum BackgroundQuality {
  clean,
  slightlyBusy,
  distracting,
}

class BackgroundAnalyzer {
  BackgroundQuality quality = BackgroundQuality.clean;
  String feedback = "";

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

    double total = 0;
    double totalSq = 0;
    int count = 0;

    // Sample outside face region
    for (int y = 0; y < height; y += 8) {
      for (int x = 0; x < width; x += 8) {
        if (x > startX &&
            x < endX &&
            y > startY &&
            y < endY) {
          continue; // skip face area
        }

        final brightness =
            CameraImageLuminance.sample(image, x, y, width, height);

        total += brightness;
        totalSq += brightness * brightness;
        count++;
      }
    }

    if (count == 0) return;

    double mean = total / count;
    double variance =
        (totalSq / count) - (mean * mean);

    _evaluateVariance(variance);
  }

  void _evaluateVariance(double variance) {
    String newFeedback = "";
    BackgroundQuality newQuality =
        BackgroundQuality.clean;

    if (variance < 400) {
      newFeedback = "";
      newQuality = BackgroundQuality.clean;
    } else if (variance < 900) {
      newFeedback =
          "Background slightly busy — step forward";
      newQuality = BackgroundQuality.slightlyBusy;
    } else {
      newFeedback =
          "Background distracting — simplify scene";
      newQuality = BackgroundQuality.distracting;
    }

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