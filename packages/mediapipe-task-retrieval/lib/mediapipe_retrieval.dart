/// Google's MediaPipe retrieval tasks: Universal Embedder, which puts text,
/// images and audio in one embedding space, and Semantic Retriever, an
/// on-device vector index over them, on Android, iOS, macOS, Linux, Windows
/// and the web.
///
/// `UniversalEmbedder` and `SemanticRetriever` have `static create(options)`,
/// Google's verbs (`embedText`, `embedImage`, `embedAudio`;
/// `insertDocument`, `insertImage`, `insertAudio`, `insertContent`,
/// `retrieve`, `delete`, `deleteAll`, `getAllRecordIds`), a `delegate` getter
/// and `dispose()`. What a platform's runtime cannot do throws
/// `RuntimeUnavailableException`, and the `query...Capabilities()` functions
/// report it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show RetrievalModels;
export 'src/capabilities.dart'
    show
        querySemanticRetrieverCapabilities,
        queryUniversalEmbedderCapabilities,
        semanticRetrieverCapabilitiesForPlatform,
        universalEmbedderCapabilitiesForPlatform;
export 'src/retrieval_tasks.dart' show SemanticRetriever, UniversalEmbedder;
export 'src/types/content.dart' hide checkSource;
export 'src/types/options.dart';
export 'src/types/results.dart';
