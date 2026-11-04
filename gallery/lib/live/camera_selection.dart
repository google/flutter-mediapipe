import 'package:camera/camera.dart';

CameraDescription? cameraForLensDirection(
  Iterable<CameraDescription> cameras,
  CameraLensDirection direction,
) {
  for (final camera in cameras) {
    if (camera.lensDirection == direction) return camera;
  }
  return null;
}

bool hasFrontAndBackCameras(Iterable<CameraDescription> cameras) =>
    cameraForLensDirection(cameras, CameraLensDirection.front) != null &&
    cameraForLensDirection(cameras, CameraLensDirection.back) != null;

CameraDescription? oppositeFacingCamera(
  Iterable<CameraDescription> cameras,
  CameraDescription? current,
) {
  final direction = current?.lensDirection == CameraLensDirection.front
      ? CameraLensDirection.back
      : CameraLensDirection.front;
  return cameraForLensDirection(cameras, direction);
}
