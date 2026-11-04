// Copyright 2023 The MediaPipe Authors.
// Licensed under the Apache License, Version 2.0.
// Generated from MediaPipe v1.0.0's Python API.
// Regenerate: tool/generate_landmark_connections.py

// dart format off

/// Google's `HandLandmarksConnections`: the hand drawing edges, in the
/// original index order.
abstract final class HandLandmarksConnections {
  /// Official HAND_CONNECTIONS (21 edges).
  static const List<(int, int)> all = [
    (0, 1), (1, 5), (9, 13), (13, 17), (5, 9), (0, 17), (1, 2), (2, 3), (3, 4),
    (5, 6), (6, 7), (7, 8), (9, 10), (10, 11), (11, 12), (13, 14), (14, 15),
    (15, 16), (17, 18), (18, 19), (19, 20),
  ];
  /// Official HAND_PALM_CONNECTIONS (6 edges).
  static const List<(int, int)> palm = [
    (0, 1), (1, 5), (9, 13), (13, 17), (5, 9), (0, 17),
  ];
  /// Official HAND_THUMB_CONNECTIONS (3 edges).
  static const List<(int, int)> thumb = [
    (1, 2), (2, 3), (3, 4),
  ];
  /// Official HAND_INDEX_FINGER_CONNECTIONS (3 edges).
  static const List<(int, int)> indexFinger = [
    (5, 6), (6, 7), (7, 8),
  ];
  /// Official HAND_MIDDLE_FINGER_CONNECTIONS (3 edges).
  static const List<(int, int)> middleFinger = [
    (9, 10), (10, 11), (11, 12),
  ];
  /// Official HAND_RING_FINGER_CONNECTIONS (3 edges).
  static const List<(int, int)> ringFinger = [
    (13, 14), (14, 15), (15, 16),
  ];
  /// Official HAND_PINKY_FINGER_CONNECTIONS (3 edges).
  static const List<(int, int)> pinkyFinger = [
    (17, 18), (18, 19), (19, 20),
  ];
}

/// Google's `PoseLandmarksConnections`: the pose drawing edges, in the
/// original index order.
abstract final class PoseLandmarksConnections {
  /// Official POSE_LANDMARKS (35 edges).
  static const List<(int, int)> all = [
    (0, 1), (1, 2), (2, 3), (3, 7), (0, 4), (4, 5), (5, 6), (6, 8), (9, 10),
    (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
    (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20), (11, 23),
    (12, 24), (23, 24), (23, 25), (24, 26), (25, 27), (26, 28), (27, 29),
    (28, 30), (29, 31), (30, 32), (27, 31), (28, 32),
  ];
}
// dart format on
