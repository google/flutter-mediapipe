import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/embed_page.dart';
import 'package:mediapipe_gallery/ui/similarity.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

const _platform = TaskPlatform(
  operatingSystem: 'macos',
  architecture: 'arm64',
  version: '15.0',
);

GalleryTask get _task => supportedTasks(_platform, {'image_embedder'}).single;

Future<void> _pumpEmbedPage(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: EmbedPage(task: _task, platform: _platform),
    ),
  );
  await tester.pump();
}

void main() {
  test('Image Embedder compares still images, with no camera', () {
    expect(_task.demo, GalleryDemo.embed);
    expect(_task.live, isFalse);
  });

  testWidgets('a wide window shows the images side by side', (tester) async {
    await _pumpEmbedPage(tester, const Size(1280, 900));
    final first = tester.getTopLeft(find.text('IMAGE 1'));
    final second = tester.getTopLeft(find.text('IMAGE 2'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    for (final sample in embedSamples) {
      expect(find.text(sample.label), findsNWidgets(2));
    }
    expect(find.byTooltip('Upload image 1'), findsOneWidget);
    expect(find.byTooltip('Upload image 2'), findsOneWidget);
    expect(find.text('COSINE SIMILARITY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone stacks both images above the similarity on one '
      'screen', (tester) async {
    await _pumpEmbedPage(tester, const Size(393, 852));
    final first = tester.getTopLeft(find.text('IMAGE 1'));
    final second = tester.getTopLeft(find.text('IMAGE 2'));
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
    final card = tester.getRect(
      find.byKey(const ValueKey('image-embedder-similarity')),
    );
    expect(card.top, greaterThan(second.dy));
    expect(card.bottom, lessThanOrEqualTo(852));
    expect(tester.takeException(), isNull);
  });
}
