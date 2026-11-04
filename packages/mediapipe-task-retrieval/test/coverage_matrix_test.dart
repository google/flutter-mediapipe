import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';
import 'package:mediapipe_retrieval/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the retrieval claims, read with the
// platform plugin registered and a hardware WebGPU adapter, as CI's browsers
// run them.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'universal_embedder': universalEmbedderCapabilitiesForPlatform,
  'semantic_retriever': semanticRetrieverCapabilitiesForPlatform,
};

Never _unused(Map<String, Object?> options) => throw UnimplementedError();

void main() {
  setUpAll(() => retrievalBackendFactory = _unused);
  tearDownAll(() => retrievalBackendFactory = null);

  test('coverage matrix agrees with the retrieval capability claims', () {
    expect(coverageMatrixProblems(_claims, webGpu: hardwareWebGpu), isEmpty);
  });
}
