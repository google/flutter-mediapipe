/// Google's native Universal Embedder on its own worker isolate, so loading
/// the model, every embedding and every retrieval stay off the calling
/// isolate.
library;

import 'package:mediapipe_core/task_worker.dart';

import '../retrieval_backend.dart';
import '../types/options.dart';
import 'native_retrieval.dart';

/// Opens Google's Universal Embedder on a worker.
Future<RetrievalBackend> openNativeUniversalEmbedder(
  UniversalEmbedderOptions options,
) async {
  requireRetrievalRuntime();
  final worker = _RetrievalWorker();
  await worker.start(options, NativeUniversalEmbedder.new);
  return worker;
}

/// Requests in order, then one close, on a worker that owns the native
/// embedder and its retrievers.
final class _RetrievalWorker
    extends TaskWorker<Map<String, Object?>, Object?, Never>
    implements RetrievalBackend {
  _RetrievalWorker() : super('UniversalEmbedder');
}
