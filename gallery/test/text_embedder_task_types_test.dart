import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';
import 'package:mediapipe_gallery/text_page.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

/// The task types of Google's Text Embedder guide, in its order:
/// https://developers.google.com/edge/mediapipe/solutions/text/text_embedder
const _guide = {
  'Retrieval (Document)': EmbeddingType.retrievalDocument,
  'Retrieval (Query)': EmbeddingType.retrievalQuery,
  'Semantic Similarity': EmbeddingType.semanticSimilarity,
  'Classification': EmbeddingType.classification,
  'Clustering': EmbeddingType.clustering,
  'Question Answering': EmbeddingType.questionAnswering,
  'Fact Checking': EmbeddingType.factChecking,
  'Code Retrieval': EmbeddingType.codeRetrieval,
};

void main() {
  final setting = taskSettings['text_embedder']!
      .whereType<ChoiceSetting>()
      .singleWhere((setting) => setting.key == 'taskType');

  test('Task Type lists the guide task types, each as its own choice', () {
    expect(setting.options, _guide.keys);
    expect(gemmaTypes, _guide.values);
  });

  test('Task Type starts on Semantic Similarity', () {
    expect(setting.options[setting.initial], 'Semantic Similarity');
    expect(gemmaTypes[setting.initial], EmbeddingType.semanticSimilarity);
  });

  test('Retrieval (Document) formats both texts as documents', () {
    final (first, second) = gemmaFormats(EmbeddingType.retrievalDocument);
    expect(first.taskType, EmbeddingType.retrievalDocument);
    expect(second.taskType, EmbeddingType.retrievalDocument);
    expect(second.role, first.role);
  });

  test('Retrieval (Query) compares a query with a retrieval document', () {
    final (first, second) = gemmaFormats(EmbeddingType.retrievalQuery);
    expect(first.taskType, EmbeddingType.retrievalQuery);
    expect(first.role, TextRole.query);
    expect(second.taskType, EmbeddingType.retrievalDocument);
    expect(second.role, TextRole.document);
  });

  test('question, fact and code uses pair a query with its document', () {
    for (final type in [
      EmbeddingType.questionAnswering,
      EmbeddingType.factChecking,
      EmbeddingType.codeRetrieval,
    ]) {
      final (first, second) = gemmaFormats(type);
      expect(first.taskType, type);
      expect(first.role, TextRole.query);
      expect(second.taskType, type);
      expect(second.role, TextRole.document);
    }
  });

  test('the other uses format both texts alike', () {
    for (final type in [
      EmbeddingType.semanticSimilarity,
      EmbeddingType.classification,
      EmbeddingType.clustering,
    ]) {
      final (first, second) = gemmaFormats(type);
      expect((first.taskType, first.role), (type, TextRole.query));
      expect((second.taskType, second.role), (type, TextRole.query));
    }
  });
}
