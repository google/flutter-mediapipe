import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:test/test.dart';

// The browser families load Google's runtime from resolve(Uri.base).
void main() {
  final page = Uri.parse('https://example.com/app/index.html');
  tearDown(
    () => MediaPipeWebRuntime.baseUrl = MediaPipeWebRuntime.defaultBaseUrl,
  );

  test('the runtime loads from jsDelivr unless the app sets baseUrl', () {
    expect(MediaPipeWebRuntime.resolve(page), 'https://cdn.jsdelivr.net/npm/');
  });

  test('a mirror named without its trailing slash is still a folder', () {
    MediaPipeWebRuntime.baseUrl = 'https://unpkg.com';
    expect(MediaPipeWebRuntime.resolve(page), 'https://unpkg.com/');
  });

  test('a folder the app serves resolves against the page', () {
    MediaPipeWebRuntime.baseUrl = 'mediapipe';
    expect(
      MediaPipeWebRuntime.resolve(page),
      'https://example.com/app/mediapipe/',
    );
  });
}
