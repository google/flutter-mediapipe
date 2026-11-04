import 'dart:io';

import 'package:mediapipe_audio/models.dart';
import 'package:test/test.dart';

void main() {
  test('byName lists every pinned model by its snake_case name', () {
    final source = File('lib/models.dart').readAsStringSync();
    final body = RegExp(
      r'abstract final class AudioModels \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(source)!.group(1)!;
    String snake(String name) => name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match[0]!.toLowerCase()}',
    );
    final declared = {
      for (final match in RegExp(r'static const (\w+) =').allMatches(body))
        if (match[1] != 'byName') snake(match[1]!),
    };
    expect(AudioModels.byName.keys.toSet(), declared);
    expect(
      AudioModels.byName.values.map((model) => model.sha256).toSet(),
      hasLength(AudioModels.byName.length),
    );
  });
}
