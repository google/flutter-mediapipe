@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  test('browser frames are accepted in browsers', () {
    final image = VisionImage.fromBrowserFrame(Object(), width: 4, height: 3);
    expect(image.width, 4);
    expect(image.height, 3);
    expect(image.browserFrame, isNotNull);
    expect(
      () => VisionImage.fromBrowserFrame(Object(), width: 0, height: 3),
      throwsArgumentError,
    );
  });
}
