// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

extension EnumeratableList<T> on List<T> {
  /// Invokes the callback on each element of the list, optionally stopping
  /// after [max] (inclusive) invocations.
  Iterable<S> enumerate<S>(S Function(T, int) fn, {int? max}) sync* {
    int count = 0;
    while (count < length) {
      yield fn(this[count], count);
      count++;

      if (max != null && count >= max) {
        return;
      }
    }
  }
}

extension EnumeratableIterable<T> on Iterable<T> {
  /// Invokes the callback on each element of the iterable, optionally stopping
  /// after [max] (inclusive) invocations.
  Iterable<S> enumerate<S>(S Function(T, int) fn, {int? max}) sync* {
    int count = 0;
    for (final T obj in this) {
      yield fn(obj, count);
      count++;

      if (max != null && count >= max) {
        return;
      }
    }
  }
}
