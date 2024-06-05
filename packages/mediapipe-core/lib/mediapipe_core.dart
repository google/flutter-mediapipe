// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Package containing core dependencies for MediaPipe's text, vision, and
/// audio-based tasks.
library mediapipe_core;

export 'src/extensions.dart';
export 'src/ffi_utils.dart';
export 'src/interface/containers.dart' show EmbeddingType;
export 'universal_mediapipe_core.dart'
    if (dart.library.html) 'src/web/mediapipe_core.dart'
    if (dart.library.io) 'src/io/mediapipe_core.dart';
