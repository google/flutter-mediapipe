/// The model's audio input, read from its bytes as Google's audio tasks read
/// it: no Google API returns it, and a stream needs it for its checks, its
/// clock and, in browsers, its framing.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The window, rate and channels of a model's audio input, from its input
/// tensor and that tensor's `AudioProperties` metadata, as
/// mediapipe/tasks/cc/audio/utils/audio_tensor_specs.cc derives them.
@immutable
final class AudioModelSpecs {
  /// Specs as Google derives them; [read] takes them from a model.
  const AudioModelSpecs({
    required this.windowSamples,
    required this.sampleRate,
    required this.channels,
  });

  /// Frames per model window: the input tensor's last dimension divided by
  /// [channels]. Windows never overlap in Google's audio tasks.
  final int windowSamples;

  /// The rate the model reads, in Hz.
  final int sampleRate;

  /// Values per frame the model reads; a mono model mixes any input down.
  final int channels;

  /// Microseconds from one window's timestamp to the next, rounded as
  /// Google's `AudioToTensorCalculator` rounds them: 975,000 for YAMNet.
  int get stepMicroseconds => (windowSamples / sampleRate * 1000000).round();

  /// Reads the specs from a TFLite [model] that Google's runtime accepted.
  /// Throws [FormatException] whose message names what is missing.
  static AudioModelSpecs read(Uint8List model) {
    final file = _Flatbuffer(model, 'the model');
    final root = file.root();
    final subgraph = file.element(
      file.reference(root, _modelSubgraphs, 'subgraphs'),
      0,
      'the first subgraph',
    );
    final inputs = file.reference(subgraph, _subgraphInputs, 'its inputs');
    final tensors = file.reference(subgraph, _subgraphTensors, 'its tensors');
    if (file.length(inputs) == 0) {
      throw const FormatException('missing the input tensor');
    }
    final tensor = file.element(
      tensors,
      file.int32At(inputs, 0),
      'the input tensor',
    );
    final shape = file.reference(tensor, _tensorShape, "the input's shape");
    final dimensions = file.length(shape);
    if (dimensions == 0) {
      throw const FormatException("missing the input's dimensions");
    }
    final lastDimension = file.int32At(shape, dimensions - 1);

    final metadata = _Flatbuffer(_metadataBytes(file, root), 'the metadata');
    final properties = _audioProperties(metadata);
    final sampleRate = metadata.uint32(properties, _audioSampleRate) ?? 0;
    final channels = metadata.uint32(properties, _audioChannels) ?? 0;
    if (sampleRate < 1) {
      throw const FormatException("missing the input's sample rate");
    }
    if (channels < 1) {
      throw const FormatException("missing the input's channel count");
    }
    if (lastDimension < channels || lastDimension % channels != 0) {
      throw FormatException(
        "the input's last dimension ($lastDimension) is not a whole number "
        'of $channels-channel frames',
      );
    }
    return AudioModelSpecs(
      windowSamples: lastDimension ~/ channels,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioModelSpecs &&
      other.windowSamples == windowSamples &&
      other.sampleRate == sampleRate &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(windowSamples, sampleRate, channels);

  @override
  String toString() =>
      'AudioModelSpecs($windowSamples samples, $sampleRate Hz, '
      '$channels channel(s))';
}

// Each field's vtable offset, as Google's generated readers in the 1.0.0
// wheel give them (mediapipe/tasks/metadata/schema_py_generated.py and
// metadata_schema_py_generated.py).
const _modelSubgraphs = 8, _modelBuffers = 12, _modelMetadata = 16;
const _subgraphTensors = 4, _subgraphInputs = 6;
const _tensorShape = 4;
const _bufferData = 4, _bufferOffset = 6, _bufferSize = 8;
const _metadataName = 4, _metadataBuffer = 6;
const _modelMetadataSubgraphs = 10;
const _subgraphMetadataInputs = 8;
const _tensorMetadataContent = 10;
const _contentType = 4, _contentProperties = 6;
const _audioSampleRate = 4, _audioChannels = 6;

/// The members of `ContentProperties` in metadata_schema.fbs.
const _audioProperties4 = 4;
const _contentNames = {
  1: 'FeatureProperties',
  2: 'ImageProperties',
  3: 'BoundingBoxProperties',
};

/// The `TFLITE_METADATA` buffer: inline, or, in a model over 2 GB, stored
/// after the flatbuffer by offset and size.
Uint8List _metadataBytes(_Flatbuffer file, int root) {
  final entries = file.reference(root, _modelMetadata, 'TFLITE_METADATA');
  for (var i = 0; i < file.length(entries); i++) {
    final entry = file.element(entries, i, 'a metadata entry');
    if (file.string(entry, _metadataName) != 'TFLITE_METADATA') continue;
    final buffer = file.element(
      file.reference(root, _modelBuffers, 'buffers'),
      file.uint32(entry, _metadataBuffer) ?? 0,
      "TFLITE_METADATA's buffer",
    );
    if (file.optionalReference(buffer, _bufferData) case final data?
        when file.length(data) > 0) {
      return file.bytes(data + 4, file.length(data));
    }
    // TFLite counts an offset as set only when it is above 1.
    final offset = file.uint64(buffer, _bufferOffset) ?? 0;
    final size = file.uint64(buffer, _bufferSize) ?? 0;
    if (offset > 1 && size > 0) return file.bytes(offset, size);
    throw const FormatException("missing TFLITE_METADATA's contents");
  }
  throw const FormatException('missing TFLITE_METADATA');
}

/// Where the input tensor's `AudioProperties` table is in [metadata].
int _audioProperties(_Flatbuffer metadata) {
  if (!metadata.hasIdentifier('M001')) {
    throw const FormatException('TFLITE_METADATA is not model metadata');
  }
  final root = metadata.root();
  final subgraph = metadata.element(
    metadata.reference(root, _modelMetadataSubgraphs, 'subgraph metadata'),
    0,
    "the first subgraph's metadata",
  );
  final tensor = metadata.element(
    metadata.reference(subgraph, _subgraphMetadataInputs, 'input metadata'),
    0,
    "the input's metadata",
  );
  final content = metadata.reference(
    tensor,
    _tensorMetadataContent,
    "the input's content",
  );
  final type = metadata.uint8(content, _contentType) ?? 0;
  if (type != _audioProperties4) {
    final found = _contentNames[type];
    throw FormatException(
      "missing the input's AudioProperties"
      '${found == null ? '' : ' (it has $found)'}',
    );
  }
  return metadata.reference(
    content,
    _contentProperties,
    "the input's AudioProperties",
  );
}

/// Bounds-checked reads of a little-endian flatbuffer. A model Google's
/// runtime accepted reads cleanly; anything else ends in a
/// [FormatException], never in a [RangeError].
final class _Flatbuffer {
  _Flatbuffer(this._bytes, this._name) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  final String _name;

  void _need(int position, int size) {
    if (position < 0 || size < 0 || position + size > _bytes.length) {
      throw FormatException('$_name is truncated');
    }
  }

  int _read(int position, int size) {
    _need(position, size);
    return switch (size) {
      1 => _data.getUint8(position),
      2 => _data.getUint16(position, Endian.little),
      _ => _data.getUint32(position, Endian.little),
    };
  }

  int _int32(int position) {
    _need(position, 4);
    return _data.getInt32(position, Endian.little);
  }

  bool hasIdentifier(String identifier) =>
      _bytes.length >= 8 && String.fromCharCodes(_bytes, 4, 8) == identifier;

  /// The root table.
  int root() => _read(0, 4);

  /// Where [field] of the table at [table] is stored, or null when the
  /// table leaves it out.
  int? _field(int table, int field) {
    final vtable = table - _int32(table);
    if (field >= _read(vtable, 2)) return null;
    final offset = _read(vtable + field, 2);
    return offset == 0 ? null : table + offset;
  }

  int? uint8(int table, int field) => switch (_field(table, field)) {
    final at? => _read(at, 1),
    null => null,
  };

  int? uint32(int table, int field) => switch (_field(table, field)) {
    final at? => _read(at, 4),
    null => null,
  };

  /// A 64-bit field, read in two halves so that a browser, whose numbers
  /// are exact to 2^53, never rounds it; no larger offset fits in memory.
  int? uint64(int table, int field) {
    final at = _field(table, field);
    if (at == null) return null;
    final high = _read(at + 4, 4);
    if (high >= 1 << 21) throw FormatException('$_name is truncated');
    return high * 0x100000000 + _read(at, 4);
  }

  /// The table, vector or string a reference field points to.
  int reference(int table, int field, String what) =>
      optionalReference(table, field) ??
      (throw FormatException('missing $what'));

  int? optionalReference(int table, int field) =>
      switch (_field(table, field)) {
        final at? => at + _read(at, 4),
        null => null,
      };

  int length(int vector) => _read(vector, 4);

  int int32At(int vector, int index) {
    if (index < 0 || index >= length(vector)) {
      throw FormatException('$_name is truncated');
    }
    return _int32(vector + 4 + 4 * index);
  }

  /// The table at [index] of a vector of tables.
  int element(int vector, int index, String what) {
    if (index < 0 || index >= length(vector)) {
      throw FormatException('missing $what');
    }
    final at = vector + 4 + 4 * index;
    return at + _read(at, 4);
  }

  String? string(int table, int field) {
    final start = optionalReference(table, field);
    if (start == null) return null;
    final size = length(start);
    return utf8.decode(bytes(start + 4, size), allowMalformed: true);
  }

  Uint8List bytes(int start, int size) {
    _need(start, size);
    return Uint8List.sublistView(_bytes, start, start + size);
  }
}
