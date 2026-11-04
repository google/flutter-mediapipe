import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:mediapipe_decision/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the Decision Maker claims, read with the
// platform plugin registered and a hardware WebGPU adapter, as CI's browsers
// run it.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'decision_maker': decisionMakerCapabilitiesForPlatform,
};

Never _unused(Map<String, Object?> options) => throw UnimplementedError();

void main() {
  setUpAll(() => decisionBackendFactory = _unused);
  tearDownAll(() => decisionBackendFactory = null);

  test('coverage matrix agrees with the decision capability claims', () {
    expect(coverageMatrixProblems(_claims, webGpu: hardwareWebGpu), isEmpty);
  });
}
