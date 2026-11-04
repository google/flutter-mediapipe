import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/camera_selection.dart';

void main() {
  const front = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 0,
  );
  const backWide = CameraDescription(
    name: 'back-wide',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  );
  const backUltraWide = CameraDescription(
    name: 'back-ultrawide',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  );

  test('flip selects the opposite direction instead of the next device', () {
    const cameras = [front, backWide, backUltraWide];

    expect(oppositeFacingCamera(cameras, front), backWide);
    expect(oppositeFacingCamera(cameras, backWide), front);
    expect(oppositeFacingCamera(cameras, backUltraWide), front);
  });

  test('flip is available only when front and back both exist', () {
    expect(hasFrontAndBackCameras(const [front, backWide]), isTrue);
    expect(hasFrontAndBackCameras(const [backWide, backUltraWide]), isFalse);
    expect(hasFrontAndBackCameras(const [front]), isFalse);
  });
}
