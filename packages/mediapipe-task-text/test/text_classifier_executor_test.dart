import 'dart:io' as io;
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:path/path.dart' as path;
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/tasks/text_classification/text_classification_executor.dart';

void main() {
  final pathToModel = path.joinAll([
    io.Directory.current.absolute.path,
    'example/assets/bert_classifier.tflite',
  ]);
  final modelBytes = io.File(pathToModel).readAsBytesSync();

  group('TextClassifierExecutor should', () {
    test('run a task', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      expect(result.timestamp, isNotNull);
      executor.close();
    });

    test('run multiple tasks', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      expect(result.timestamp, isNotNull);
      final TextClassifierResult result2 = executor.classify('Hello, world!');
      expect(result2.timestamp, isNotNull);
      executor.close();
    });

    test('unpack a result', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(2));
      expect(classifications.categories.first.categoryName, equals('positive'));
      expect(classifications.categories.first.score, closeTo(0.9919, 0.0001));
      expect(classifications.categories.last.categoryName, equals('negative'));
      expect(classifications.categories.last.score, closeTo(0.00804, 0.00001));
      executor.close();
    });

    test('use the denylist', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(
          modelBytes,
          classifierOptions: ClassifierOptions(
            categoryDenylist: ['positive'],
          ),
        ),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(1));
      // expect(classifications.categories.first.categoryName, equals('positive'));
      // expect(classifications.categories.first.score, closeTo(0.9919, 0.0001));
      expect(classifications.categories.first.categoryName, equals('negative'));
      expect(classifications.categories.first.score, closeTo(0.00804, 0.00001));
      executor.close();
    });

    test('use the allowlist', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(
          modelBytes,
          classifierOptions: ClassifierOptions(
            categoryAllowlist: ['positive'],
          ),
        ),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(1));
      expect(classifications.categories.first.categoryName, equals('positive'));
      expect(classifications.categories.first.score, closeTo(0.9919, 0.0001));
      executor.close();
    });

    test('release all resources', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      executor.classify('Hello, world!');
      executor.close();
      expect(executor.textClassifierPointer, isNull);
      expect(executor.textClassifierPointer, isNull);
      expect(executor.optionsPtr, isNull);
      expect(executor.resultsPtr, isNull);
      expect(executor.createErrorMessage, isNull);
      expect(executor.classifyErrorMessage, isNull);
      expect(executor.closeErrorMessage, isNull);
    });
  });
}
