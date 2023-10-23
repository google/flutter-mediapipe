import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

void main() {
  group('FFI-based TextClassifier.classify should', () {
    final classifier = TextClassifier(
      options: TextClassifierOptions.fromAssetPath('fake'),
    );

    test('return results from C', () {
      _verifyResults(classifier.classifySync('some text'));
    });

    test('return results from C asynchronously', () async {
      _verifyResults(await classifier.classify('some text'));
    });
  });
}

void _verifyResults(TextClassifierResult result) {
  expect(result.timestamp, const Duration(milliseconds: 300));
  expect(result.classifications.length, 1);

  final classifications = result.classifications.first;
  expect(classifications.headName, 'Whatever');
  expect(classifications.headIndex, 1);
  expect(classifications.categories.length, 2);

  final categories = result.classifications.first.categories;
  expect(categories.first.index, 0);
  expect(categories.first.score, closeTo(0.9, 0.001));
  expect(categories.first.categoryName, 'some text');
  expect(categories.first.displayName, 'some text');

  expect(categories.last.index, 1);
  expect(categories.last.score, closeTo(0.7, 0.001));
  expect(categories.last.categoryName, 'some text');
  expect(categories.last.displayName, 'some text');
}
