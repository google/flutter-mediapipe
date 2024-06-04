// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Package containing core dependencies for MediaPipe's text, vision, and
/// audio-based tasks.
library mediapipe_core;

export 'universal_mediapipe_genai.dart'
    if (dart.library.html) 'src/web/mediapipe_genai.dart'
    if (dart.library.io) 'src/io/mediapipe_genai.dart';
