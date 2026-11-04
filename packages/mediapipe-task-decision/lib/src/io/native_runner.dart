/// Google's native Decision Maker on its own worker isolate, so loading the
/// model and every evaluation stay off the calling isolate.
library;

import 'package:mediapipe_core/task_worker.dart';

import '../decision_backend.dart';
import '../types/options.dart';
import 'native_decision_maker.dart';

/// Opens Google's Decision Maker on a worker.
Future<DecisionBackend> openNativeDecisionMaker(
  DecisionMakerOptions options,
) async {
  requireDecisionRuntime();
  final worker = _DecisionWorker();
  await worker.start(options, NativeDecisionMaker.new);
  return worker;
}

/// Requests in order, then one close, on a worker that owns the native task.
final class _DecisionWorker
    extends TaskWorker<Map<String, Object?>, Object?, Never>
    implements DecisionBackend {
  _DecisionWorker() : super('DecisionMaker');
}
