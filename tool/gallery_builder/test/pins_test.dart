import 'dart:io';

import 'package:gallery_builder/models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The names in a family's `XxxModels.byName`, read from its
/// `lib/models.dart`, which this tool cannot import.
Set<String> _byName(String family) {
  final source = File(
    p.join('..', '..', 'packages', packageOf(family), 'lib', 'models.dart'),
  ).readAsStringSync();
  final start = source.indexOf('static const byName');
  final block = source.substring(start, source.indexOf('};', start));
  return RegExp(
    r"'(\w+)':",
  ).allMatches(block).map((match) => match.group(1)!).toSet();
}

void main() {
  test('the gallery runs a task from every family', () {
    final families = [
      for (final entry in Directory(p.join('..', '..', 'packages')).listSync())
        if (p.basename(entry.path).startsWith('mediapipe-task-'))
          p.basename(entry.path),
    ]..sort();
    final covered = {
      for (final model in models.values) packageOf(model.family),
    };
    expect(covered.toList()..sort(), families);
    expect(() => packageOf('mediapipe_core'), throwsArgumentError);
  });

  for (final MapEntry(key: task, value: model) in models.entries) {
    test('$task lists a model ${model.family} can bundle', () {
      expect(
        _byName(model.family),
        contains(model.name),
        reason:
            '${model.name} is not in packages/${packageOf(model.family)}/'
            'lib/models.dart byName',
      );
    });
  }
}
