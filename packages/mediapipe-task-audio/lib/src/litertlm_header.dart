/// What a `.litertlm` bundle's own header says about where its models run,
/// read without loading the model.
library;

import 'dart:typed_data';

/// The bytes before a LiteRT-LM header's flatbuffer: the magic, the version
/// and where the header ends.
const litertlmPreambleBytes = 32;

/// A LiteRT-LM header's end, from its first [litertlmPreambleBytes] bytes, or
/// null when [preamble] is not the start of a version 1 bundle.
int? litertlmHeaderEnd(Uint8List preamble) {
  if (preamble.length < litertlmPreambleBytes) return null;
  if (String.fromCharCodes(preamble, 0, 8) != 'LITERTLM') return null;
  final data = ByteData.sublistView(preamble);
  if (data.getUint32(8, Endian.little) != 1) return null;
  // A 64-bit field; a header past 4 GB is not one.
  if (data.getUint32(28, Endian.little) != 0) return null;
  return data.getUint32(24, Endian.little);
}

/// Whether [header], a bundle's bytes up to its header's end, marks a section
/// `backend_constraint: gpu`. The LiteRT community's Kokoro bundle
/// (`kokoro_int8_gpu_fp16.litertlm`) marks its vocoder `gpu` and its acoustic
/// model `cpu`, which is where Google's Text to Speech runs them on the GPU
/// delegate; Phonon marks none. Null when [header] is not a LiteRT-LM header.
bool? litertlmHasGpuSection(Uint8List header) {
  try {
    return _sectionConstraints(header)?.contains('gpu');
  } on RangeError {
    return null;
  }
}

/// Every section's `backend_constraint`, from the header's flatbuffer:
/// LiteRTLMMetaData.section_metadata, SectionMetadata.objects, then each
/// SectionObject's items, key-value pairs whose value is a union.
Set<String>? _sectionConstraints(Uint8List header) {
  final end = litertlmHeaderEnd(header);
  if (end == null || end > header.length) return null;
  final buffer = _Flatbuffer(
    ByteData.sublistView(header, litertlmPreambleBytes, end),
  );
  final root = buffer.root();
  final sections = buffer.table(root, 1);
  if (sections == null) return null;
  final constraints = <String>{};
  for (final section in buffer.tables(sections, 0)) {
    for (final item in buffer.tables(section, 0)) {
      if (buffer.string(item, 0) != 'backend_constraint') continue;
      if (buffer.byte(item, 1) != _stringValue) continue;
      if (buffer.table(item, 2) case final value?) {
        if (buffer.string(value, 0) case final constraint?) {
          constraints.add(constraint);
        }
      }
    }
  }
  return constraints;
}

/// The `StringValue` member of the header schema's `VData` union.
const _stringValue = 9;

/// Just enough of the flatbuffer format to read tables, vectors of tables,
/// strings and bytes, each by field index.
final class _Flatbuffer {
  _Flatbuffer(this._data);

  final ByteData _data;

  int _u32(int at) => _data.getUint32(at, Endian.little);

  int root() => _u32(0);

  /// Where field [index] of the table at [table] is, or null when absent.
  int? _field(int table, int index) {
    final vtable = table - _data.getInt32(table, Endian.little);
    final slot = 4 + 2 * index;
    if (slot >= _data.getUint16(vtable, Endian.little)) return null;
    final offset = _data.getUint16(vtable + slot, Endian.little);
    return offset == 0 ? null : table + offset;
  }

  int _target(int at) => at + _u32(at);

  int? table(int table, int index) => switch (_field(table, index)) {
    final at? => _target(at),
    null => null,
  };

  Iterable<int> tables(int table, int index) sync* {
    final at = _field(table, index);
    if (at == null) return;
    final vector = _target(at);
    for (var i = 0; i < _u32(vector); i++) {
      yield _target(vector + 4 + 4 * i);
    }
  }

  String? string(int table, int index) {
    final at = _field(table, index);
    if (at == null) return null;
    final start = _target(at);
    return String.fromCharCodes(
      Uint8List.sublistView(_data, start + 4, start + 4 + _u32(start)),
    );
  }

  int? byte(int table, int index) => switch (_field(table, index)) {
    final at? => _data.getUint8(at),
    null => null,
  };
}
