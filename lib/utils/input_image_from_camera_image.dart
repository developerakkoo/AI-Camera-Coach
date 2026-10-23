import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Builds [InputImage] for ML Kit from a [CameraImage], matching the official
/// [google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter) camera example.
class InputImageFromCameraImage {
  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Returns null if the stream format is unsupported or orientation is unknown.
  static InputImage? build({
    required CameraImage image,
    required CameraController controller,
  }) {
    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation270deg;
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid) {
      if (format == InputImageFormat.nv21 && image.planes.length == 1) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }
      if (image.planes.length == 3) {
        final nv21 = _yuv420888ToNv21(image);
        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      }
      return null;
    }

    if (Platform.isIOS) {
      if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
        return null;
      }
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return null;
  }

  /// YUV_420_888 (three planes) to NV21 single buffer.
  static Uint8List _yuv420888ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = width * height;
    final out = Uint8List(ySize + (ySize >> 1));

    final yBuffer = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    var outIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        out[outIndex++] =
            yBuffer[y * yRowStride + x * yPixelStride];
      }
    }

    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    final uvWidth = width >> 1;
    final uvHeight = height >> 1;
    var uvOut = ySize;
    for (var y = 0; y < uvHeight; y++) {
      for (var x = 0; x < uvWidth; x++) {
        final uIndex = y * uRowStride + x * uPixelStride;
        final vIndex = y * vRowStride + x * vPixelStride;
        out[uvOut++] = vBuffer[vIndex];
        out[uvOut++] = uBuffer[uIndex];
      }
    }

    return out;
  }
}

/// Luminance sampling for [CameraImage] (BGRA on iOS, NV21 Y plane on Android).
class CameraImageLuminance {
  static bool useYPlane(CameraImage image) {
    if (Platform.isIOS) return false;
    if (image.planes.isEmpty) return false;
    final bpp = image.planes.first.bytesPerPixel;
    return bpp == null || bpp == 1;
  }

  static double sample(CameraImage image, int x, int y, int width, int height) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;

    if (useYPlane(image)) {
      if (x < 0 || y < 0 || x >= width || y >= height) return 0;
      final i = y * rowStride + x;
      if (i >= bytes.length) return 0;
      return bytes[i].toDouble();
    }

    final idx = (y * width + x) * 4;
    if (idx + 2 >= bytes.length) return 0;
    final b = bytes[idx];
    final g = bytes[idx + 1];
    final r = bytes[idx + 2];
    return 0.299 * r + 0.587 * g + 0.114 * b;
  }
}
