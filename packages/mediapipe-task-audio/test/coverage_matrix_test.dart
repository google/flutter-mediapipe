import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the audio claims, read with the platform
// plugin registered, as in an app.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'audio_classifier': audioClassifierCapabilitiesForPlatform,
  'audio_transcriber': audioTranscriberCapabilitiesForPlatform,
  'text_to_speech': textToSpeechCapabilitiesForPlatform,
};

Never _unused(Map<String, Object?> options) => throw UnimplementedError();

// The iPhone GPU claims that wait for a device test in CI, as the vision
// package's do. Remove each one once its cell is 'device'.
const _unprovedGpu = {'audio_transcriber / ios'};

const _arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');

void main() {
  test('32-bit Android runs the Audio Classifier on the CPU', () {
    expect(audioClassifierCapabilitiesForPlatform(_arm32).supportedDelegates, {
      Delegate.cpu,
    });
  });

  setUpAll(() {
    audioTaskBackendFactory = _unused;
    audioTranscriberOpener = (_) => throw UnimplementedError();
    browserOnMac = true;
  });
  tearDownAll(() {
    audioTaskBackendFactory = null;
    audioTranscriberOpener = null;
    browserOnMac = false;
  });

  test('coverage matrix agrees with the audio capability claims', () {
    expect(
      coverageMatrixProblems(
        _claims,
        webGpu: hardwareWebGpu,
        unprovedGpu: _unprovedGpu,
      ),
      isEmpty,
    );
  });

  test('the check refuses a GPU claim the matrix does not prove', () {
    // The transcriber's iPhone GPU, whose matrix cell is still pending.
    expect(
      coverageMatrixProblems(_claims, webGpu: hardwareWebGpu),
      contains(startsWith('audio_transcriber / ios / gpu is claimed but')),
    );
    expect(
      coverageMatrixProblems(
        _claims,
        webGpu: hardwareWebGpu,
        unprovedGpu: {..._unprovedGpu, 'text_to_speech / macos'},
      ),
      [
        'text_to_speech / macos / gpu is listed as unproved but marked '
            '"required"',
      ],
    );
  });
}
