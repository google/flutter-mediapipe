/// Where one text task runs: the registered browser adapter (Google's
/// JavaScript runtime), or Google's native runtime on a worker isolate.
/// Every task class forwards here, on every platform.
library;

import 'dart:async';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import '../text_task_backend.dart';
import '../types/format_context.dart';

/// A Text Embedder request: the text and its optional format context.
typedef TextEmbedderInput = (String, TextFormatContext?);

/// A request as a platform backend takes it: the text and the arguments
/// Google's runtime takes with it, named as in its JavaScript API.
typedef BackendRequest = (String text, Map<String, Object?> arguments);

/// One task's requests, on whichever runtime serves it. [I] is the request:
/// the text, or the text and its format context.
abstract interface class TextTaskRunner<I, R> {
  /// Runs [input] after every request submitted before it.
  Future<R> run(I input);

  /// Waits for accepted requests, then closes Google's task once.
  Future<void> dispose();
}

/// A runner that can also stream a request's partial results.
abstract interface class TextStreamRunner<I, R, U>
    implements TextTaskRunner<I, R> {
  /// Starts on listen; cancelling stops delivery, not Google's generation.
  Stream<U> stream(I input);
}

/// The checks every text request gets on every platform before it reaches
/// Google's runtime, so the same call fails the same way everywhere.
final class TextTaskSession<I, R> {
  /// Wraps [runner]; [name] appears in errors.
  TextTaskSession(this.name, this.runner);

  /// The task's name, as its errors say it.
  final String name;

  /// The runtime serving the task.
  final TextTaskRunner<I, R> runner;

  Future<void>? _disposing;

  /// Rejects a request after disposal or with text Google's C API would
  /// truncate.
  void check(String text) {
    if (_disposing != null) throw StateError('$name has been disposed.');
    if (text.contains('\u0000')) {
      throw ArgumentError.value(text, 'text', 'Must not contain NUL.');
    }
  }

  /// Checks [text], then runs [input]; errors arrive through the Future.
  Future<R> run(String text, I input) async {
    check(text);
    return runner.run(input);
  }

  /// Waits for accepted requests and closes the task; repeated calls return
  /// the same completion.
  Future<void> dispose() => _disposing ??= runner.dispose();
}

/// Opens a classic text task (Text Classifier, Text Embedder or Language
/// Detector) after [capabilities] admits the delegate: through the
/// registered platform backend as Google's [task], with [settings] named as
/// in Google's JavaScript API, [request] turning each input into the text
/// and its per-call arguments, and [decode] reading its results, or else on
/// Google's native runtime through [native].
Future<TextTaskRunner<I, R>> openClassicTextTask<I, R, O extends TaskOptions>(
  O options, {
  required Future<TaskCapabilities> Function() capabilities,
  required String task,
  required Map<String, Object?> settings,
  required R Function(Map<String, dynamic> json) decode,
  required BackendRequest Function(I input) request,
  required Future<TextTaskRunner<I, R>> Function(O options) native,
}) async {
  requireDelegate(await capabilities(), options.delegate);
  await resolveTaskModel(options);
  if (textTaskBackendFactory case final factory?) {
    final backend = await BackendTextTask.open(factory, task, {
      'modelBytes': options.modelBytes,
      'modelPath': options.modelPath,
      'delegate': options.delegate.name.toUpperCase(),
      ...settings,
    }, decode);
    return _BackendInput(backend, request);
  }
  return native(options);
}

/// Opens a generative text task (Proofreader or Summarizer) on Google's
/// native runtime through [native], after [capabilities] admits the
/// delegate. Browsers have neither task, which [capabilities] reports.
Future<TextStreamRunner<String, R, U>>
openGenerativeTextTask<R, U, O extends TaskOptions>(
  O options, {
  required Future<TaskCapabilities> Function() capabilities,
  required Future<TextStreamRunner<String, R, U>> Function(O options) native,
}) async {
  requireDelegate(await capabilities(), options.delegate);
  await resolveTaskModel(options);
  return native(options);
}

/// A format context named as Google's JavaScript `TextFormatOptions`.
Map<String, Object?> formatContextSettings(TextFormatContext context) => {
  'type': _embeddingTypes[context.taskType]!,
  'title': ?context.title,
  'textRole': context.role == TextRole.document ? 'DOCUMENT' : 'QUERY',
};

const _embeddingTypes = {
  EmbeddingType.retrievalQuery: 'RETRIEVAL_QUERY',
  EmbeddingType.retrievalDocument: 'RETRIEVAL_DOCUMENT',
  EmbeddingType.semanticSimilarity: 'SEMANTIC_SIMILARITY',
  EmbeddingType.classification: 'CLASSIFICATION',
  EmbeddingType.clustering: 'CLUSTERING',
  EmbeddingType.questionAnswering: 'QUESTION_ANSWERING',
  EmbeddingType.factChecking: 'FACT_CHECKING',
  EmbeddingType.codeRetrieval: 'CODE_RETRIEVAL',
};

/// One of Google's text tasks on a platform plugin's backend: requests run
/// in submission order and disposal waits for them.
final class BackendTextTask<R> implements TextTaskRunner<BackendRequest, R> {
  BackendTextTask._(this._backend, this._decode);

  /// Creates Google's [task] with [options] through [factory].
  static Future<BackendTextTask<R>> open<R>(
    Future<TextTaskBackend> Function(String, Map<String, Object?>) factory,
    String task,
    Map<String, Object?> options,
    R Function(Map<String, dynamic> json) decode,
  ) async {
    try {
      return BackendTextTask._(await factory(task, options), decode);
    } catch (error) {
      throw taskException(error);
    }
  }

  final TextTaskBackend _backend;
  final R Function(Map<String, dynamic> json) _decode;
  final _queue = SerialTaskQueue('Text task');

  @override
  Future<R> run(BackendRequest request) => _queue.add(
    () async => _decode(await _backend.run(request.$1, request.$2)),
  );

  @override
  Future<void> dispose() => _queue.close(_backend.dispose);
}

/// Adapts a backend to a task whose requests carry more than text, such as
/// the embedder's format context, which [_request] turns into the backend's
/// arguments.
final class _BackendInput<I, R> implements TextTaskRunner<I, R> {
  _BackendInput(this._backend, this._request);
  final BackendTextTask<R> _backend;
  final BackendRequest Function(I input) _request;

  @override
  Future<R> run(I input) async => _backend.run(_request(input));

  @override
  Future<void> dispose() => _backend.dispose();
}
