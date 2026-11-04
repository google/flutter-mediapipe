import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the text claims, read with the platform
// plugin registered, as in an app.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'text_classifier': textClassifierCapabilitiesForPlatform,
  'language_detector': languageDetectorCapabilitiesForPlatform,
  'text_embedder': textEmbedderCapabilitiesForPlatform,
  'embedding_gemma': (p) =>
      textEmbedderCapabilitiesForPlatform(p, model: TextModels.embeddingGemma),
  'text_proofreader': textProofreaderCapabilitiesForPlatform,
  'text_summarizer': textSummarizerCapabilitiesForPlatform,
};

Never _unused(String task, Map<String, Object?> options) =>
    throw UnimplementedError();

void main() {
  setUpAll(() => textTaskBackendFactory = _unused);
  tearDownAll(() => textTaskBackendFactory = null);

  test('coverage matrix agrees with the text capability claims', () {
    expect(coverageMatrixProblems(_claims), isEmpty);
  });
}
