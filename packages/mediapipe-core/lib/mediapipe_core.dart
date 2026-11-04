/// What every MediaPipe task family shares, identical on Android, iOS, macOS,
/// Linux, Windows and the web: the options base, the delegate, the value
/// types results are made of, the exceptions, the model store and the
/// capability types. Each family's library exports it, so apps need not
/// import this package directly.
library;

export 'src/capabilities/task_capabilities.dart'
    show BrowserEngine, RuntimeTargets, TaskCapabilities, TaskPlatform;
export 'src/delegate.dart';
export 'src/download_asset.dart' show DownloadAsset, DownloadFailure;
export 'src/exceptions.dart';
export 'src/model_download_exception.dart';
export 'src/model_source.dart';
export 'src/model_store_io.dart'
    if (dart.library.js_interop) 'src/model_store_web.dart';
export 'src/task_options.dart' show TaskOptions;
export 'src/value_types.dart' hide cosineSimilarity;
export 'src/web_runtime.dart';

// TODO: Give apps Google's runtime logs through Dart. Nothing does today.
// See packages/mediapipe-core/tool/RUNTIME_LOGS.md.
