import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_gallery/catalog.dart' show preferredDelegate;
import 'package:mediapipe_gallery/main.dart' show GalleryAssets;
import 'package:mediapipe_gallery/retrieval_page.dart'
    show retrievalSampleDocuments;
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

// The retrieval tasks inside the gallery app, beside the other runtimes:
// Google's per-family retrieval library must load and answer as Google's
// Python API does on every platform. The package's native test covers every
// reference case; this checks the app build, its model download and the
// runtime together.
const _query = 'A puppy playing fetch outside.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the retrieval tasks answer as Google\'s Python API does', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final assets = await GalleryAssets.unpack();
      if (!assets.bundledTasks.contains('universal_embedder')) {
        markTestSkipped('This build bundles no retrieval tasks.');
        return;
      }
      final capabilities = await queryUniversalEmbedderCapabilities();
      if (!capabilities.isSupported) {
        await expectLater(
          UniversalEmbedder.create(
            UniversalEmbedderOptions(
              model: RetrievalModels.embeddingGemma2TextVision,
            ),
          ),
          throwsA(isA<RuntimeUnavailableException>()),
        );
        markTestSkipped('Retrieval: ${capabilities.unavailableReasons}');
        return;
      }
      // Google's 388 MB model, downloaded and verified once into the model
      // cache (natively), or fetched by Google's runtime (in browsers).
      final embedder = await UniversalEmbedder.create(
        UniversalEmbedderOptions(
          modelPath: await GalleryAssets.downloadedModelPath(
            RetrievalModels.embeddingGemma2TextVision,
          ),
          delegate: preferredDelegate(capabilities.supportedDelegates),
        ),
      );
      try {
        // Another platform's build of Google's engine may round differently
        // from the macOS wheel the expectations came from.
        const tolerance = 0.02;
        final query = (await embedder.embedText(_query)).embeddings.single;
        final dog = (await embedder.embedText(
          retrievalSampleDocuments[0],
        )).embeddings.single;
        final cat = (await embedder.embedText(
          retrievalSampleDocuments[5],
        )).embeddings.single;
        expect(query.length, 768);
        expect(
          UniversalEmbedder.cosineSimilarity(query, dog),
          closeTo(0.8175923, tolerance),
        );
        expect(
          UniversalEmbedder.cosineSimilarity(query, cat),
          closeTo(0.565313, tolerance),
        );

        final retriever = await SemanticRetriever.create(
          SemanticRetrieverOptions(embedder: embedder),
        );
        try {
          for (final (i, text) in retrievalSampleDocuments.indexed) {
            await retriever.insertDocument(
              'doc-${i + 1}',
              text,
              metadata: {'topic': i == 0 || i == 5 ? 'animals' : 'other'},
            );
          }
          final result = await retriever.retrieve(_query, limit: 3);
          expect(result.records, hasLength(3));
          // The dog document, then the cat and the recipe, which score within
          // 0.01 of each other and may swap on another platform.
          expect(result.records.first.id, 'doc-1');
          expect(result.records.first.score, closeTo(0.8175923, tolerance));
          expect(result.records.skip(1).map((r) => r.id).toSet(), {
            'doc-6',
            'doc-2',
          });
          final animals = await retriever.retrieve(
            'How do I bake a cake?',
            limit: 3,
            minSimilarity: 0,
            metadataFilter: {'topic': 'animals'},
          );
          expect(animals.records.map((r) => r.id), ['doc-1', 'doc-6']);
          expect((await retriever.getAllRecordIds())..sort(), [
            for (var i = 1; i <= 6; i++) 'doc-$i',
          ]);
          await retriever.delete('doc-6');
          expect(await retriever.getAllRecordIds(), hasLength(5));
        } finally {
          await retriever.dispose();
        }
      } finally {
        await embedder.dispose();
      }
    });
  });
}
