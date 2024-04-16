// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shortens long strings for logging, printing, etc.
extension DebuggableString on String {
  /// Shortens the string to its first X characters, replacing the rest with an
  /// ellipses and the total length. If the string is equal to or shorter than
  /// the given length, then [shorten] is a no-op.
  String shorten([int x = 10]) {
    if (length <= x) return this;
    return '${substring(0, x)}...[$length]';
  }
}
