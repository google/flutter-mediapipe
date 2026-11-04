import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the audio claims, read with the platform
// plugin registered, as in an app.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'audio_classifier': audioClassifierCapabilitiesForPlatform,
};

Never _unused(Map<String, Object?> options) => throw UnimplementedError();

const _arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');

void main() {
  test('32-bit Android runs the Audio Classifier on the CPU', () {
    expect(audioClassifierCapabilitiesForPlatform(_arm32).supportedDelegates, {
      Delegate.cpu,
    });
  });

  setUpAll(() => audioTaskBackendFactory = _unused);
  tearDownAll(() => audioTaskBackendFactory = null);

  test('coverage matrix agrees with the audio capability claims', () {
    expect(coverageMatrixProblems(_claims), isEmpty);
  });
}
