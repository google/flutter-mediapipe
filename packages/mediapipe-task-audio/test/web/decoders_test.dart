@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/src/decoders.dart';

void main() {
  test('chunks keep every head, their stamps and absent labels', () {
    final results = decodeAudioClassifierResults(
      jsonDecode('''[
        {"timestampMs": 0, "classifications": [{"headIndex": 0,
          "headName": "scores", "categories": [{"index": 0, "score": 0.9,
          "categoryName": "Speech", "displayName": ""}]}]},
        {"timestampMs": 975, "classifications": [{"headIndex": 0,
          "headName": "", "categories": []}, {"headIndex": 1,
          "headName": "music", "categories": [{"index": 132, "score": 0.5,
          "categoryName": "Music", "displayName": "Music"}]}]}
      ]''')
          as List,
    );
    expect(results.map((r) => r.timestampMilliseconds), [0, 975]);
    final speech = results.first.classifications.single;
    expect(speech.headName, 'scores');
    expect(speech.categories.single.categoryName, 'Speech');
    expect(speech.categories.single.displayName, isNull);
    expect(results.last.classifications, hasLength(2));
    expect(results.last.classifications.first.headName, isNull);
    expect(() => results.first.classifications.clear(), throwsUnsupportedError);
  });

  test('a chunk without classifications decodes as empty', () {
    final [result] = decodeAudioClassifierResults([
      {'timestampMs': 0},
    ]);
    expect(result.classifications, isEmpty);
  });

  test('options are checked as on native platforms', () {
    expect(
      () => AudioClassifierOptions(modelPath: 'yamnet', maxResults: 0),
      throwsArgumentError,
    );
  });
}
