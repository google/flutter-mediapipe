@TestOn('vm')
library;

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_decision/src/capabilities.dart'
    show decisionRuntimeTargets;
import 'package:test/test.dart';

// The capability tables answer for the library the hook bundles: the
// per-family decision library (familyRuntimes).
void main() {
  test('the runtime targets are the hook\'s library targets', () {
    // The simulator and 32-bit arm libraries serve the ios/arm64 and
    // android/arm64 process targets' builds.
    expect(
      decisionRuntimeTargets.keys.toSet(),
      familyRuntimes['decision']!.keys.toSet().difference({
        'ios-simulator/arm64',
        'android/arm',
      }),
    );
  });
}
