// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

extension EnumeratableList<T> on List<T> {
  Iterable<S> enumerate<S>(S Function(T, int) fn) sync* {
    int count = 0;
    while (count < length) {
      yield fn(this[count], count);
      count++;
    }
  }
}

extension EnumeratableIterable<T> on Iterable<T> {
  Iterable<S> enumerate<S>(S Function(T, int) fn) sync* {
    int count = 0;
    for (final T obj in this) {
      yield fn(obj, count);
      count++;
    }
  }
}
