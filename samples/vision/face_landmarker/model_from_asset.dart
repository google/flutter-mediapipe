import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<FaceLandmarker> createFromAsset() async {
  final asset = await rootBundle.load('assets/models/face_landmarker.task');
  return FaceLandmarker.create(
    FaceLandmarkerOptions(
      modelBytes: asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      ),
    ),
  );
}
