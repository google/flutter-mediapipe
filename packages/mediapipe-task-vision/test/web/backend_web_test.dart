@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  test(
    'validates model options and preserves the requested GPU delegate',
    () async {
      // Browser unit-test asset serving differs from the deployed package path;
      // the full API is exercised through the gallery integration harness.
      expect(
        () => FaceLandmarkerOptions(modelBytes: Uint8List(0)),
        throwsArgumentError,
      );
      final options = FaceLandmarkerOptions(
        modelBytes: Uint8List.fromList([1]),
        delegate: Delegate.gpu,
      );
      expect(options.delegate, Delegate.gpu);
    },
  );
}
