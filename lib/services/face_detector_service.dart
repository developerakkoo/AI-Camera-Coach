import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Future<List<Face>> detectFaces(InputImage image) async {
    return await _faceDetector.processImage(image);
  }

  void dispose() {
    _faceDetector.close();
  }
}