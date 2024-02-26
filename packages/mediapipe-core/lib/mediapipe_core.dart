// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Package containing core dependencies for MediaPipe's text, vision, and
/// audio-based tasks.
library;

export 'src/interface/interface.dart';
export 'universal_mediapipe_core.dart'
    if (dart.library.html) 'web_mediapipe_core.dart'
    if (dart.library.io) 'io_mediapipe_core.dart';
