/// Browsers have no native runtime: the retrieval tasks run through the
/// registered browser plugin, so reaching this means it did not register.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show pluginNotRegistered;

import '../retrieval_backend.dart';
import '../types/options.dart';

/// The native Universal Embedder; browsers have none.
Future<RetrievalBackend> openNativeUniversalEmbedder(
  UniversalEmbedderOptions options,
) async => throw pluginNotRegistered('mediapipe_retrieval');
