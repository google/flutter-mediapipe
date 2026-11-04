@TestOn('vm')
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart'
    show ActivationDataType, ChunkingMode;
import 'package:mediapipe_retrieval/src/io/third_party/mediapipe/retrieval_bindings.dart'
    as mp;
import 'package:test/test.dart';

/// The struct sizes Google's Python ctypes declare, recorded with the
/// reference answers (tool/generate_reference.py).
final _sizes =
    (jsonDecode(
              File(
                'test/fixtures/embedding_gemma_2_text_vision_reference.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>)['structSizes']!
        as Map<String, Object?>;

void main() {
  final dart = <String, int>{
    'MpUniversalEmbedderOptions': sizeOf<mp.MpUniversalEmbedderOptions>(),
    'MpBaseOptions': sizeOf<mp.MpBaseOptions>(),
    'MpKeyValuePair': sizeOf<mp.MpKeyValuePair>(),
    'MpSemanticRetrieverOptions': sizeOf<mp.MpSemanticRetrieverOptions>(),
    'MpRetrievalRecord': sizeOf<mp.MpRetrievalRecord>(),
    'MpRetrievalResult': sizeOf<mp.MpRetrievalResult>(),
    'MpRecordIdsResult': sizeOf<mp.MpRecordIdsResult>(),
    'MpTextPart': sizeOf<mp.MpTextPart>(),
    'MpImagePart': sizeOf<mp.MpImagePart>(),
    'MpAudioPart': sizeOf<mp.MpAudioPart>(),
    'MpTaskPart': sizeOf<mp.MpTaskPart>(),
  };
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    test('$name is laid out as Google\'s Python declares it', () {
      expect(dart[name], size, reason: name);
    });
  }
  // The native task passes both enums by index, so each value must sit at its
  // number in Google's headers, which core keeps.
  test('ActivationDataType and ChunkingMode are numbered as Google\'s', () {
    String capitalized(String name) =>
        name[0].toUpperCase() + name.substring(1);
    expect(
      _headerEnum(
        'retrieval/universal_embedder/universal_embedder.h',
        'MpActivationDataType',
      ),
      {
        for (final type in ActivationDataType.values)
          type == ActivationDataType.modelDefault
                  ? 'Default'
                  : capitalized(type.name):
              type.index,
      },
    );
    expect(
      _headerEnum(
        'retrieval/semantic_retriever/semantic_retriever.h',
        'MpChunkingMode',
      ),
      {
        for (final mode in ChunkingMode.values)
          capitalized(mode.name): mode.index,
      },
    );
  });
  test('every bound struct is checked', () {
    expect(dart.keys.toSet(), _sizes.keys.toSet());
  });
}

/// [name]'s values in one of Google's C headers, keyed without the `k<name>`
/// prefix: `kMpChunkingModeWord = 1` is `Word: 1`.
Map<String, int> _headerEnum(String header, String name) {
  final source = File(
    '../mediapipe-core/native/include/$header',
  ).readAsStringSync();
  final body = RegExp('enum $name \\{([^}]*)\\}').firstMatch(source)!.group(1)!;
  return {
    for (final value in RegExp('k$name(\\w+) = (\\d+)').allMatches(body))
      value.group(1)!: int.parse(value.group(2)!),
  };
}
