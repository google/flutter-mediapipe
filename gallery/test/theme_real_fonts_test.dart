import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'support/scripted_camera.dart';

const _macos = TaskPlatform(
  operatingSystem: 'macos',
  architecture: 'arm64',
  version: '15.0',
);

/// Every task any build bundles, by the id the manifest gives it.
const _bundled = {
  'face_landmarker',
  'hand_landmarker',
  'pose_landmarker',
  'gesture_recognizer',
  'holistic_landmarker',
  'face_detector',
  'object_detector',
  'image_classifier',
  'image_segmenter',
  'image_embedder',
  'interactive_segmenter',
  'audio_classifier',
  'language_detector',
  'text_classifier',
  'text_embedder',
  'embedding_gemma',
  'text_proofreader',
  'text_summarizer',
  'decision_maker',
  'universal_embedder',
  'semantic_retriever',
};

/// Tall enough to keep the whole sidebar built and in reach of a tap.
const _tall = 1600.0;

/// A phone held upright, or a short laptop window.
const _short = 640.0;

const _widths = [
  320.0,
  360.0,
  390.0,
  600.0,
  768.0,
  800.0,
  1199.0,
  1200.0,
  1280.0,
  1440.0,
];

/// Runs the drawer's and the page's transitions to their end. Not
/// pumpAndSettle: a page's spinner never settles.
Future<void> _finishTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  // A tap that misses would leave a page unchecked and the test green.
  WidgetController.hitTestWarningShouldBeFatal = true;

  late Directory samples;

  // Widget tests draw every family in a square test font, unless it is loaded.
  setUpAll(() async {
    final roboto = FontLoader('Roboto');
    for (final weight in [400, 500, 700]) {
      final bytes = File('fonts/Roboto-$weight.ttf').readAsBytesSync();
      roboto.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await roboto.load();
    samples = Directory.systemTemp.createTempSync('gallery-samples-');
    final image = await rootBundle.load('assets/samples/animals.jpg');
    File('${samples.path}/animals.jpg').writeAsBytesSync(
      image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes),
    );
  });

  tearDownAll(() => samples.deleteSync(recursive: true));

  test('the bundled family is what the theme draws with', () {
    final style = galleryTheme(
      Brightness.light,
    ).textTheme.bodyMedium!.copyWith(fontSize: 14);
    expect(style.fontFamily, 'Roboto');
    expect(style.letterSpacing, 0);
    final painter = TextPainter(
      text: TextSpan(text: 'MediaPipe Flutter Gallery', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    // Square glyphs would make this one font size per letter.
    expect(painter.width, lessThan(25 * 14 * 0.7));
  });

  for (final width in _widths) {
    testWidgets('every page lays out at $width wide', (tester) async {
      final previous = CameraPlatform.instance;
      CameraPlatform.instance = ScriptedCamera(cameras: const []);
      addTearDown(() => CameraPlatform.instance = previous);
      tester.view.physicalSize = Size(width, _tall);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> expectLaysOut(String what) async {
        expect(tester.takeException(), isNull, reason: what);
        tester.view.physicalSize = Size(width, _short);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$what, short');
        tester.view.physicalSize = Size(width, _tall);
        await tester.pump();
      }

      final tasks = [
        for (final task in supportedTasks(_macos, _bundled))
          if (task.hasOwnPage) task,
      ];
      expect(tasks, isNotEmpty);
      await tester.pumpWidget(
        MaterialApp(
          theme: galleryTheme(Brightness.light),
          home: galleryShell(
            GalleryAssets(samples, const {'tasks': <String>[]}),
            _macos,
            tasks,
          ),
        ),
      );
      await tester.pump();
      await expectLaysOut('the home page');

      final wide = width >= Sizes.wide;
      for (final task in tasks) {
        if (!wide) {
          await tester.tap(find.byTooltip('Open navigation'));
          await _finishTransitions(tester);
          await expectLaysOut('the drawer');
        }
        // The sidebar's entry comes first; the drawer's is built last.
        final entry = find.text(task.title);
        await tester.tap(wide ? entry.first : entry.last);
        await _finishTransitions(tester);
        await expectLaysOut(task.id);
      }

      // Replaced so the page's own timers and tasks end with the test.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
