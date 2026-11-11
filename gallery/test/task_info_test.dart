import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_gallery/ui/workspace.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets('the task guide is a link that opens outside the gallery', (
    tester,
  ) async {
    final task = supportedTasks(
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '15',
      ),
      const {'face_detector'},
    ).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: galleryTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTaskInfo(context, task),
            child: const Text('Info'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    final link = tester.widget<Link>(find.byType(Link));
    expect(link.target, LinkTarget.blank);
    expect(
      link.uri,
      Uri.parse(
        'https://ai.google.dev/edge/mediapipe/solutions/vision/face_detector',
      ),
    );
  });

  testWidgets('Text Embedder passes the Gemma terms on with EmbeddingGemma', (
    tester,
  ) async {
    const macos = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '15',
    );
    const bundled = {'text_embedder', 'embedding_gemma'};
    // EmbeddingGemma is a model of the Text Embedder tile, not a tile.
    final task = supportedTasks(macos, bundled).single;
    expect(task.runtimeId, 'text_embedder');
    expect(offersEmbeddingGemma(macos, bundled), isTrue);
    expect(offersEmbeddingGemma(macos, const {'text_embedder'}), isFalse);
    var gemmaTerms = false;
    // The test font is wider than the gallery's, so the dialog needs height.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: galleryTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaskInfo(context, task, gemmaTerms: gemmaTerms),
            child: const Text('Info'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.byType(GemmaNotice), findsNothing);
    expect(
      tester.widget<Link>(find.byType(Link)).uri,
      Uri.parse(
        'https://ai.google.dev/edge/mediapipe/solutions/text/text_embedder',
      ),
    );
    Navigator.of(tester.element(find.byType(Link))).pop();
    await tester.pumpAndSettle();

    gemmaTerms = true;
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.byType(GemmaNotice), findsOneWidget);
  });
}
