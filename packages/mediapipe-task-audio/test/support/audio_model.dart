/// TFLite models built by the tests, with only what Google's audio tasks read
/// of a model's input: the input tensor's shape and its `AudioProperties`
/// metadata (lib/src/stream/model_specs.dart). Each field sits at the vtable
/// offset Google's generated readers use.
library;

import 'dart:typed_data';

/// What the model's metadata holds for its input: `AudioProperties`,
/// `ImageProperties`, a tensor with no content, or no `TFLITE_METADATA` at
/// all.
enum ModelContent { audio, image, none, noMetadata }

/// A model whose input reads [window] frames of [channels] values at [rate],
/// with its `TFLITE_METADATA` stored inline or, as in a model over 2 GB, by
/// offset after the flatbuffer.
Uint8List audioModel({
  required int window,
  required int rate,
  required int channels,
  ModelContent content = ModelContent.audio,
  bool metadataByOffset = false,
}) {
  final metadata = _Writer().finish(
    _Table({
      10: [
        _Table({
          8: [
            _Table({
              if (content case ModelContent.audio || ModelContent.image)
                10: _Table({
                  4: _U8(content == ModelContent.audio ? 4 : 2),
                  6: content == ModelContent.audio
                      ? _Table({4: _U32(rate), 6: _U32(channels)})
                      : _Table({}),
                }),
            }),
          ],
        }),
      ],
    }),
    identifier: 'M001',
  );
  final offset = _U64(0);
  final writer = _Writer();
  final model = writer.finish(
    _Table({
      4: _U32(3),
      8: [
        _Table({
          4: [
            _Table({
              4: _Ints([1, window * channels]),
              6: _U8(0),
            }),
          ],
          6: _Ints([0]),
        }),
      ],
      12: [
        _Table({}),
        metadataByOffset
            ? _Table({6: offset, 8: _U64(metadata.length)})
            : _Table({4: _Bytes(metadata)}),
      ],
      16: [
        _Table({4: _Bytes('min_runtime_version'.codeUnits), 6: _U32(0)}),
        if (content != ModelContent.noMetadata)
          _Table({4: _Bytes('TFLITE_METADATA'.codeUnits), 6: _U32(1)}),
      ],
    }),
    identifier: 'TFL3',
  );
  if (!metadataByOffset) return model;
  // The buffer's offset counts from the start of the file. Two 32-bit
  // halves, since browsers compiled with dart2js have no 64-bit accessor.
  final file = Uint8List(model.length + metadata.length)
    ..setAll(0, model)
    ..setAll(model.length, metadata);
  ByteData.sublistView(file)
    ..setUint32(writer.positions[offset]!, model.length, Endian.little)
    ..setUint32(writer.positions[offset]! + 4, 0, Endian.little);
  return file;
}

final class _U8 {
  _U8(this.value);
  final int value;
}

final class _U32 {
  _U32(this.value);
  final int value;
}

final class _U64 {
  _U64(this.value);
  final int value;
}

final class _Ints {
  _Ints(this.values);
  final List<int> values;
}

final class _Bytes {
  _Bytes(this.bytes);
  final List<int> bytes;
}

/// A table's fields by vtable offset: scalars, or a table, a vector of
/// tables (a list), a vector of ints or bytes, which the table references.
final class _Table {
  _Table(this.fields);
  final Map<int, Object> fields;
}

/// Lays a flatbuffer out front to back: each table's vtable, then the table,
/// then what it references, so every reference points forward.
final class _Writer {
  final _bytes = <int>[];

  /// Where each 64-bit field was written, for patching after the fact.
  final positions = Map<_U64, int>.identity();

  int _reserve(int size, {int align = 4}) {
    while (_bytes.length % align != 0) {
      _bytes.add(0);
    }
    final at = _bytes.length;
    _bytes.addAll(List.filled(size, 0));
    return at;
  }

  void _put(int at, int value, int size) {
    for (var i = 0; i < size; i++) {
      _bytes[at + i] = (value >> (8 * i)) & 0xff;
    }
  }

  /// A reference at [at] to whatever [node] is laid out as.
  void _refer(int at, Object node) => _put(at, _place(node) - at, 4);

  int _place(Object node) {
    switch (node) {
      case _Table table:
        final slots = table.fields.isEmpty
            ? 0
            : (table.fields.keys.reduce((a, b) => a > b ? a : b) - 4) ~/ 2 + 1;
        final vtable = _reserve(4 + 2 * slots, align: 2);
        final start = _reserve(8 + 8 * slots, align: 8);
        _put(start, start - vtable, 4);
        _put(vtable, 4 + 2 * slots, 2);
        _put(vtable + 2, 8 + 8 * slots, 2);
        final references = <(int, Object)>[];
        for (final MapEntry(key: offset, value: value)
            in table.fields.entries) {
          final at = start + 8 + 8 * ((offset - 4) ~/ 2);
          _put(vtable + offset, at - start, 2);
          switch (value) {
            case _U8(:final value):
              _put(at, value, 1);
            case _U32(:final value):
              _put(at, value, 4);
            case _U64 field:
              positions[field] = at;
              _put(at, field.value, 8);
            default:
              references.add((at, value));
          }
        }
        for (final (at, value) in references) {
          _refer(at, value);
        }
        return start;
      case List<Object> tables:
        final at = _reserve(4 + 4 * tables.length);
        _put(at, tables.length, 4);
        for (final (i, table) in tables.indexed) {
          _refer(at + 4 + 4 * i, table);
        }
        return at;
      case _Ints ints:
        final at = _reserve(4 + 4 * ints.values.length);
        _put(at, ints.values.length, 4);
        for (final (i, value) in ints.values.indexed) {
          _put(at + 4 + 4 * i, value, 4);
        }
        return at;
      case _Bytes bytes:
        // A trailing zero, which strings carry and byte vectors ignore.
        final at = _reserve(4 + bytes.bytes.length + 1, align: 16);
        _put(at, bytes.bytes.length, 4);
        _bytes.setRange(at + 4, at + 4 + bytes.bytes.length, bytes.bytes);
        return at;
    }
    throw ArgumentError.value(node, 'node');
  }

  Uint8List finish(_Table root, {required String identifier}) {
    _reserve(8);
    _bytes.setRange(4, 8, identifier.codeUnits);
    _put(0, _place(root), 4);
    return Uint8List.fromList(_bytes);
  }
}
