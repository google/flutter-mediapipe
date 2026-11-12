import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/audio_page.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/decision_page.dart';
import 'package:mediapipe_gallery/embed_page.dart';
import 'package:mediapipe_gallery/fish_game_page.dart';
import 'package:mediapipe_gallery/live_page.dart';
import 'package:mediapipe_gallery/main.dart' show GalleryAssets;
import 'package:mediapipe_gallery/retrieval_page.dart';
import 'package:mediapipe_gallery/segment_page.dart';
import 'package:mediapipe_gallery/speech_page.dart';
import 'package:mediapipe_gallery/text_page.dart';
import 'package:mediapipe_gallery/transcriber_page.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_gallery/ui/workspace.dart';
import 'package:mediapipe_gallery/universal_embedder_page.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:url_launcher/link.dart';

import 'support/scripted_camera.dart';

const _macos = TaskPlatform(
  operatingSystem: 'macos',
  architecture: 'arm64',
  version: '15.0',
);

const _chromium = TaskPlatform(
  operatingSystem: 'web',
  architecture: 'unknown',
  gpu: 'WebGPU apple apple',
  browserEngine: BrowserEngine.blink,
);

/// Every tile, by id, with the package its page runs. Spelled out so a new
/// tile has to say which, and checked against the code below.
const _packages = {
  'face_landmarker_live': 'mediapipe_vision',
  'hand_landmarker_live': 'mediapipe_vision',
  'pose_landmarker_live': 'mediapipe_vision',
  'gesture_recognizer_live': 'mediapipe_vision',
  'holistic_landmarker_live': 'mediapipe_vision',
  'face_detector_live': 'mediapipe_vision',
  'object_detector_live': 'mediapipe_vision',
  'image_classifier_live': 'mediapipe_vision',
  'image_segmenter_live': 'mediapipe_vision',
  'image_embedder': 'mediapipe_vision',
  'interactive_segmenter': 'mediapipe_vision',
  'audio_classifier': 'mediapipe_audio',
  'audio_transcriber': 'mediapipe_audio',
  'text_to_speech': 'mediapipe_audio',
  'language_detector': 'mediapipe_text',
  'text_classifier': 'mediapipe_text',
  'text_embedder': 'mediapipe_text',
  'text_proofreader': 'mediapipe_text',
  'text_summarizer': 'mediapipe_text',
  'decision_maker': 'mediapipe_decision',
  'decision_fish_game': 'mediapipe_decision',
  'universal_embedder': 'mediapipe_retrieval',
  'semantic_retriever': 'mediapipe_retrieval',
};

/// The source file of each kind of page.
const _pageFiles = {
  GalleryDemo.live: 'live_page.dart',
  GalleryDemo.segment: 'segment_page.dart',
  GalleryDemo.embed: 'embed_page.dart',
  GalleryDemo.text: 'text_page.dart',
  GalleryDemo.audio: 'audio_page.dart',
  GalleryDemo.transcribe: 'transcriber_page.dart',
  GalleryDemo.speak: 'speech_page.dart',
  GalleryDemo.decision: 'decision_page.dart',
  GalleryDemo.game: 'fish_game_page.dart',
  GalleryDemo.universalEmbed: 'universal_embedder_page.dart',
  GalleryDemo.retrieve: 'retrieval_page.dart',
};

/// Every tile any build shows: no one platform runs them all.
List<(GalleryTask, TaskPlatform)> _tiles() {
  final bundled = _packages.keys.map((id) => id.replaceAll('_live', '')).toSet()
    ..remove('decision_fish_game')
    ..add('decision_maker');
  final tiles = <String, (GalleryTask, TaskPlatform)>{};
  for (final platform in [_macos, _chromium]) {
    for (final task in supportedTasks(platform, bundled)) {
      if (task.hasOwnPage) tiles[task.id] ??= (task, platform);
    }
  }
  return tiles.values.toList();
}

/// Where the Segment page finds its sample, which it reads as a file.
late Directory _samples;

/// [task]'s page, built as the home page builds it.
Widget _page(GalleryTask task, TaskPlatform platform) => switch (task.demo) {
  GalleryDemo.live => LivePage(task: task, platform: platform),
  GalleryDemo.segment => SegmentPage(
    task: task,
    assets: GalleryAssets(_samples, const {'tasks': <String>[]}),
    platform: platform,
  ),
  GalleryDemo.embed => EmbedPage(task: task, platform: platform),
  GalleryDemo.text => TextPage(task: task),
  GalleryDemo.audio => AudioPage(task: task),
  GalleryDemo.transcribe => TranscriberPage(task: task, platform: platform),
  GalleryDemo.speak => SpeechPage(task: task, platform: platform),
  GalleryDemo.decision => DecisionPage(task: task, platform: platform),
  GalleryDemo.game => FishGamePage(task: task, platform: platform),
  GalleryDemo.universalEmbed => UniversalEmbedderPage(
    task: task,
    platform: platform,
  ),
  GalleryDemo.retrieve => RetrievalPage(task: task, platform: platform),
  GalleryDemo.none => throw StateError('${task.id} has no demo'),
};

void main() {
  setUpAll(() async {
    _samples = Directory.systemTemp.createTempSync('gallery-samples-');
    final bytes = await rootBundle.load('assets/samples/animals.jpg');
    File('${_samples.path}/animals.jpg').writeAsBytesSync(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });

  test('every tile has its package listed, and every kind of page a tile', () {
    final tiles = _tiles().map((tile) => tile.$1);
    expect(tiles.map((task) => task.id).toSet(), _packages.keys.toSet());
    expect(tiles.map((task) => task.demo).toSet(), _pageFiles.keys.toSet());
  });

  test('each page imports the package it links to, and each package is the '
      'one its directory publishes', () {
    for (final (task, _) in _tiles()) {
      final package = _packages[task.id]!;
      expect(task.category.package, package, reason: task.id);
      expect(
        File('lib/${_pageFiles[task.demo]}').readAsStringSync(),
        contains("import 'package:$package/$package.dart'"),
        reason: task.id,
      );
    }
    for (final category in GalleryCategory.values) {
      expect(
        File(
          '../packages/mediapipe-task-${category.name}/pubspec.yaml',
        ).readAsLinesSync().first,
        'name: ${category.package}',
      );
    }
  });

  for (final (task, platform) in _tiles()) {
    testWidgets('${task.id} links to its package and not to GitHub', (
      tester,
    ) async {
      final previous = CameraPlatform.instance;
      CameraPlatform.instance = ScriptedCamera(cameras: const []);
      addTearDown(() => CameraPlatform.instance = previous);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: galleryTheme(Brightness.light),
          home: _page(task, platform),
        ),
      );
      await tester.pump();

      final link = tester.widget<Link>(
        find.descendant(
          of: find.byType(TaskToolbar),
          matching: find.byType(Link),
        ),
      );
      final package = _packages[task.id];
      expect(link.uri, Uri.parse('https://pub.dev/packages/$package'));
      expect(link.target, LinkTarget.blank);
      expect(find.text('$package on pub.dev'), findsOneWidget);
      expect(
        tester
            .widgetList<Link>(find.byType(Link))
            .where((link) => link.uri?.host == 'github.com'),
        isEmpty,
      );
      expect(find.text('View source'), findsNothing);
      expect(tester.takeException(), isNull);

      // Replaced so the page's own timers and tasks end with the test.
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (width, beside) in [
    (320.0, false),
    (390.0, false),
    (600.0, false),
    (800.0, true),
    (1280.0, true),
  ]) {
    testWidgets('at $width wide the link sits '
        '${beside ? 'beside' : 'under'} a switch', (tester) async {
      tester.view.physicalSize = Size(width, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final task = _tiles()
          .map((tile) => tile.$1)
          .firstWhere((task) => task.id == 'semantic_retriever');
      const lead = SizedBox(key: ValueKey('switch'), width: 240, height: 36);

      await tester.pumpWidget(
        MaterialApp(
          theme: galleryTheme(Brightness.light),
          home: Scaffold(
            body: GalleryPageBody(
              children: [TaskToolbar(task: task, leading: lead)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final link = tester.getCenter(
        find.text('mediapipe_retrieval on pub.dev'),
      );
      final top = tester.getRect(find.byKey(const ValueKey('switch')));
      if (beside) {
        expect(link.dy, closeTo(top.center.dy, 0.01));
      } else {
        expect(link.dy, greaterThan(top.bottom));
      }
    });
  }
}
