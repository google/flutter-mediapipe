/// Google's word timestamps give UTF-8 byte offsets on its native runtimes;
/// Dart strings index by UTF-16 code unit.
library;

import 'dart:typed_data';

/// For each UTF-8 byte offset of [text], as Google's word timestamps give
/// them, the UTF-16 index of the character it falls in; the last entry is
/// the text's length.
Int32List utf16Indices(String text) {
  final runes = text.runes;
  var length = 0;
  for (final rune in runes) {
    length += _utf8Length(rune);
  }
  final indices = Int32List(length + 1);
  var byte = 0, index = 0;
  for (final rune in runes) {
    final size = _utf8Length(rune);
    indices.fillRange(byte, byte + size, index);
    byte += size;
    index += rune > 0xffff ? 2 : 1;
  }
  indices[byte] = index;
  return indices;
}

/// A lone surrogate is encoded as U+FFFD, three bytes, as toNativeUtf8 and
/// JavaScript's TextEncoder do.
int _utf8Length(int rune) => rune < 0x80
    ? 1
    : rune < 0x800
    ? 2
    : rune < 0x10000
    ? 3
    : 4;
