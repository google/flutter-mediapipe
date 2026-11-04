import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// True on a device run without a camera on purpose (`SDK_CAMERA=none`):
/// every camera of the Android 9 emulator aborts it (see android.yaml), so
/// that job has none. Its system image still declares camera features, so
/// CameraX refuses to list cameras at all rather than finding none.
const runsWithoutCamera = String.fromEnvironment('SDK_CAMERA') == 'none';

/// CameraX's refusal when a device declares more cameras than it opens.
const _cameraXFoundFewer = 'less cameras than anticipated';

/// The cameras [find] lists, or none where the job runs without a camera and
/// CameraX refuses to list them.
Future<List<T>> camerasOrNone<T>(Future<List<T>> Function() find) async {
  try {
    return await find();
  } on PlatformException catch (error) {
    if (!runsWithoutCamera || !'$error'.contains(_cameraXFoundFewer)) rethrow;
    return const [];
  }
}

/// Whether [problem], the live page's message, says the device has no camera:
/// the page's own words, or CameraX's refusal where the job runs without one.
bool saysNoCamera(String problem) =>
    problem.contains('No camera found') ||
    (runsWithoutCamera && problem.contains(_cameraXFoundFewer));

/// The live page says the device has no camera.
void expectNoCameraMessage() {
  final own = find.textContaining('No camera found');
  if (runsWithoutCamera && own.evaluate().isEmpty) {
    expect(find.textContaining(_cameraXFoundFewer), findsOneWidget);
  } else {
    expect(own, findsOneWidget);
  }
}
