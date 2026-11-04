import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';
import 'package:mediapipe_gallery/audio/microphone.dart';
import 'package:mediapipe_gallery/audio_page.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/decision_page.dart';
import 'package:mediapipe_gallery/embed_page.dart';
import 'package:mediapipe_gallery/fish_game_page.dart';
import 'package:mediapipe_gallery/live/live_camera_view.dart';
import 'package:mediapipe_gallery/live/video_frame_image.dart';
import 'package:mediapipe_gallery/live_page.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/retrieval_page.dart';
import 'package:mediapipe_gallery/segment_page.dart';
import 'package:mediapipe_gallery/text_page.dart';
import 'package:mediapipe_gallery/ui/components.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_gallery/universal_embedder_page.dart';

import 'support/delegate_control.dart';
import 'support/no_camera.dart';

/// GPU coverage follows the SDK suites: 'required' on physical phones fails a
/// GPU refusal, 'skip' on emulators and simulators never tries GPU, and the
/// default 'optional' tries it and keeps to CPU after the first refusal.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');
const _gpuSkipTasks = String.fromEnvironment('SDK_GPU_SKIP_TASKS');

/// Runs every page exposed by this build through the same shell and sidebar a
/// user opens: each camera page live on every delegate it offers, switched
/// while running, then a still image on each, then the bundled video clip
/// frame by frame; Image Embedder's two images, and the segmenter, text and
/// audio pages on theirs. The picker supplies bundled image bytes without a
/// device file dialog; decoding, task creation, inference and rendering stay
/// real.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('video files decode with their timestamps and rotation', (
    tester,
  ) async {
    final assets = await tester.runAsync(GalleryAssets.unpack);
    if (!assets!.bundledTasks.contains('face_detector')) {
      markTestSkipped('This build bundles no Face Detector.');
      return;
    }
    await tester.runAsync(() => _videoFiles(assets));
  });

  testWidgets('every sidebar task opens and runs its bundled sample', (
    tester,
  ) async {
    // A tap that lands on something else, such as a closing drawer's scrim,
    // fails at that tap instead of several steps later.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    final setup = await tester.runAsync(
      () async => (
        await GalleryAssets.unpack(),
        (await queryObjectDetectorCapabilities()).platform,
      ),
    );
    expect(setup, isNotNull);
    final (assets, platform) = setup!;
    final tasks =
        supportedTasks(
          platform,
          assets.bundledTasks,
        ).where((task) => task.hasOwnPage).toList()..sort((a, b) {
          final category = a.category.index.compareTo(b.category.index);
          return category != 0 ? category : a.title.compareTo(b.title);
        });
    expect(tasks, isNotEmpty);

    Uint8List? imageBytes;
    String? imageName;
    await tester.pumpWidget(
      GalleryApp(
        stillImagePicker: () async {
          expect(imageBytes, isNotNull);
          return XFile.fromData(
            imageBytes!,
            name: imageName!,
            mimeType: 'image/jpeg',
          );
        },
        // CI machines have no microphone: the speech sample plays through
        // the microphone mode's own path instead.
        microphone: sampleMicrophone(),
      ),
    );
    // The shell's content pane exists in both layouts; the sidebar's "Home"
    // is inside a closed drawer on phones.
    await _until(
      tester,
      () => find.byKey(const ValueKey('gallery-content')).evaluate().isNotEmpty,
    );

    var gpuRefused = false;
    Set<Delegate> offered(GalleryTask task) =>
        task.capabilities(platform).supportedDelegates;
    // The delegates this run exercises, in the order a user would try them.
    List<Delegate> delegatesFor(GalleryTask task) => [
      if (offered(task).contains(Delegate.cpu)) Delegate.cpu,
      if (offered(task).contains(Delegate.gpu) &&
          _gpu != 'skip' &&
          !gpuRefused &&
          !_gpuSkipTasks.split(',').contains(task.runtimeId))
        Delegate.gpu,
    ];

    final visited = <String>[];
    final checks = <String>[];
    for (final task in tasks) {
      // One line per page, so a stalled run shows where it stopped.
      // ignore: avoid_print
      print('GALLERY_JOURNEY_PAGE ${task.id}');
      // Below the design's wide breakpoint the sidebar is a drawer.
      if (tester.getSize(find.byType(HomePage)).width < Sizes.wide) {
        await tester.tap(find.byTooltip('Open navigation'));
        await settle(tester);
      }
      final sidebar = find.byKey(const ValueKey('gallery-sidebar'));
      final tile = find.descendant(
        of: sidebar,
        matching: find.text(task.title),
      );
      final list = find
          .descendant(of: sidebar, matching: find.byType(Scrollable))
          .first;
      // scrollUntilVisible only scrolls toward the end, and leaves the tile
      // it found at the top of the list, so once the list outgrows the
      // window the next tile can sit above the viewport: start from the top.
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(tile, 250, scrollable: list);
      // scrollUntilVisible ends by jumping the list without a frame, so the
      // tile's position is stale until the list is laid out again.
      await settle(tester);
      expect(tile, findsOneWidget, reason: task.id);
      await tester.tap(tile);
      await tester.pump();
      // On phones the drawer closes over the new page, and its scrim takes
      // every tap until the drawer has gone.
      await _until(tester, () => find.byType(Drawer).evaluate().isEmpty);
      await _until(
        tester,
        () => find
            .byType(
              task.demo == GalleryDemo.live
                  ? LivePage
                  : task.demo == GalleryDemo.embed
                  ? EmbedPage
                  : task.demo == GalleryDemo.segment
                  ? SegmentPage
                  : task.demo == GalleryDemo.text
                  ? TextPage
                  : task.demo == GalleryDemo.decision
                  ? DecisionPage
                  : task.demo == GalleryDemo.game
                  ? FishGamePage
                  : task.demo == GalleryDemo.universalEmbed
                  ? UniversalEmbedderPage
                  : task.demo == GalleryDemo.retrieve
                  ? RetrievalPage
                  : AudioPage,
            )
            .evaluate()
            .isNotEmpty,
      );

      switch (task.demo) {
        case GalleryDemo.live:
          final data = await tester.runAsync(
            () => rootBundle.load('assets/samples/${task.sample}'),
          );
          expect(data, isNotNull);
          imageBytes = Uint8List.fromList(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          imageName = task.sample;
          final choices = offered(task).length > 1;
          final delegates = delegatesFor(task);
          expect(delegates, isNotEmpty, reason: task.id);
          final camera = await _cameraProblem(tester);
          if (camera != null) {
            // Emulators and phones have cameras, except a job that runs
            // without one on purpose; desktop runners and simulators may not.
            if (runsWithoutCamera) {
              expect(
                saysNoCamera(camera),
                isTrue,
                reason: '${task.id}: $camera',
              );
            } else {
              expect(
                defaultTargetPlatform,
                isNot(TargetPlatform.android),
                reason: '${task.id}: $camera',
              );
            }
            checks.add('${task.id}:camera:none');
            _note('${task.id}: no camera ($camera)');
          } else {
            for (final delegate in delegates) {
              if (choices) await tapDelegate(tester, delegate);
              final optional = delegate == Delegate.gpu && _gpu == 'optional';
              if (!await _liveFrames(tester, delegate, optional: optional)) {
                gpuRefused = true;
                _note(
                  '${task.id}: live GPU refused, CPU from here: ${screenText(tester)}',
                );
                await tapDelegate(tester, Delegate.cpu);
                break;
              }
              checks.add('${task.id}:${delegate.name}:live');
            }
          }
          final still = find.byKey(
            ValueKey('${task.runtimeId.replaceAll('_', '-')}-mode-image'),
          );
          expect(still, findsOneWidget, reason: task.id);
          await tester.ensureVisible(still);
          await tester.tap(still);
          await tester.pump();
          await _until(
            tester,
            () => find.text('Choose image').evaluate().isNotEmpty,
          );
          await tester.ensureVisible(find.text('Choose image'));
          await tester.tap(find.text('Choose image'));
          final expected = _stillResults[task.runtimeId];
          expect(expected, isNotNull, reason: '${task.id} needs a result');
          // Each delegate runs the image again, the last one first since the
          // page is already on it.
          for (final delegate in delegatesFor(task).reversed) {
            if (choices) await tapDelegate(tester, delegate);
            final optional = delegate == Delegate.gpu && _gpu == 'optional';
            if (!await _stillRan(
              tester,
              delegate,
              expected!,
              optional: optional,
            )) {
              gpuRefused = true;
              _note(
                '${task.id}: still GPU refused, CPU from here: ${screenText(tester)}',
              );
              continue;
            }
            checks.add('${task.id}:${delegate.name}:still');
          }
          expect(
            checks.where(
              (check) =>
                  check.startsWith('${task.id}:') && check.endsWith(':still'),
            ),
            isNotEmpty,
            reason: '${task.id} ran no still image',
          );
          // The video file mode runs the bundled clip in video mode, every
          // frame with the file's own timestamp.
          final video = find.byKey(
            ValueKey('${task.runtimeId.replaceAll('_', '-')}-mode-video'),
          );
          expect(video, findsOneWidget, reason: task.id);
          await tester.ensureVisible(video);
          await tester.tap(video);
          final label = await _videoRan(tester, task.id);
          checks.add('${task.id}:$label:video');
          break;
        case GalleryDemo.embed:
          // The page opens comparing Dog with Cat; each delegate compares
          // them again.
          final choices = offered(task).length > 1;
          String? similarity;
          for (final delegate in delegatesFor(task)) {
            if (choices) await tapDelegate(tester, delegate);
            final optional = delegate == Delegate.gpu && _gpu == 'optional';
            similarity = await _compared(tester, delegate, optional: optional);
            if (similarity == null) {
              gpuRefused = true;
              _note(
                '${task.id}: GPU refused, CPU from here: ${screenText(tester)}',
              );
              await tapDelegate(tester, Delegate.cpu);
              similarity = await _compared(
                tester,
                Delegate.cpu,
                optional: false,
              );
              break;
            }
            checks.add('${task.id}:${delegate.name}:compare');
          }
          expect(similarity, isNot('1.0000'), reason: 'Dog and Cat differ');
          // The same sample twice is identical.
          final dog = find.byKey(const ValueKey('image-embedder-2-dog'));
          await tester.ensureVisible(dog);
          await tester.tap(dog);
          await _until(tester, () => _similarity(tester) == '1.0000');
          // An upload replaces the first image, through the page's picker.
          final data = await tester.runAsync(
            () => rootBundle.load('assets/samples/portrait.jpg'),
          );
          imageBytes = Uint8List.fromList(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          imageName = 'portrait.jpg';
          final upload = find.byKey(const ValueKey('image-embedder-1-upload'));
          await tester.ensureVisible(upload);
          await tester.tap(upload);
          await _until(
            tester,
            () => tester
                .widgetList<Image>(
                  find.byKey(const ValueKey('image-embedder-1-image')),
                )
                .any((image) => image.semanticLabel == 'Image 1: uploaded'),
          );
          await _until(
            tester,
            () => !(_similarity(tester) ?? '1.0000').startsWith('1.0000'),
          );
          checks.add('${task.id}:upload');
          break;
        case GalleryDemo.text:
          checks.add('${task.id}:cpu:run');
          final compare = _comparingTasks.contains(task.runtimeId);
          final generative = _generativeTasks.contains(task.runtimeId);
          final run = find.text(compare ? 'Compare' : 'Run');
          await tester.ensureVisible(run);
          await tester.tap(run);
          // The generative models load hundreds of megabytes and then write
          // a few sentences; the wait allows for an emulated CPU.
          await _until(
            tester,
            () => find.textContaining('Done in').evaluate().isNotEmpty,
            attempts: generative ? 2400 : 480,
          );
          if (compare) {
            expect(find.text('Cosine similarity'), findsOneWidget);
          } else if (generative) {
            final written = tester.widget<SelectableText>(
              find.byKey(generatedTextKey),
            );
            expect(written.data?.trim(), isNotEmpty, reason: task.id);
          } else {
            final category = _textCategories[task.runtimeId];
            expect(category, isNotNull, reason: '${task.id} needs a result');
            final row = find
                .ancestor(of: find.text(category!), matching: find.byType(Row))
                .first;
            final score = tester
                .widgetList<Text>(
                  find.descendant(of: row, matching: find.byType(Text)),
                )
                .last;
            expect(
              double.parse(score.data!),
              greaterThanOrEqualTo(0.5),
              reason: task.id,
            );
          }
          break;
        case GalleryDemo.decision:
          // Each kind of question on the page's sample, which Google's
          // Python API answers the same way (the package's reference test
          // covers every case to float precision).
          for (final (kind, expected) in _decisionAnswers) {
            await tester.tap(find.byKey(ValueKey('decision-${kind.name}')));
            await tester.pump();
            final ask = find.text('Ask');
            await tester.ensureVisible(ask);
            await tester.tap(ask);
            // The first question downloads Google's 678 MB model.
            await _until(
              tester,
              () =>
                  find.byKey(decisionAnswerKey).evaluate().isNotEmpty ||
                  find.text('Error').evaluate().isNotEmpty,
              attempts: 2400,
            );
            expect(
              find.text('Error'),
              findsNothing,
              reason: '${task.id} ${kind.name}: ${screenText(tester)}',
            );
            final answer = tester.widget<Text>(find.byKey(decisionAnswerKey));
            expected(answer.data!, '${task.id} ${kind.name}');
            checks.add('${task.id}:cpu:${kind.name}');
          }
          break;
        case GalleryDemo.game:
          // The model steers the fish: Google's wording gets every sentence
          // the game writes right, so each decision matches the scene.
          await tester.tap(find.byKey(const ValueKey('fish-play')));
          // The first game downloads Google's 165 MB EmbeddingGemma 2.
          await _until(
            tester,
            () =>
                _fishScore(tester).$1 >= 5 ||
                find.text('Error').evaluate().isNotEmpty,
            attempts: 2400,
          );
          expect(
            find.text('Error'),
            findsNothing,
            reason: '${task.id}: ${screenText(tester)}',
          );
          final (decisions, matched) = _fishScore(tester);
          expect(
            matched,
            decisions,
            reason: '${task.id}: ${screenText(tester)}',
          );
          await tester.tap(find.byKey(const ValueKey('fish-play')));
          await tester.pump();
          checks.add('${task.id}:cpu:play');
          break;
        case GalleryDemo.universalEmbed:
          // The sentence about a dog against the dog photo, then against the
          // elephant: Google's model puts the matching pair closer (0.60
          // against 0.55 in its Python API).
          await tester.tap(find.byKey(const ValueKey('universal-compare')));
          await tester.pump();
          // The first comparison downloads Google's 388 MB model.
          await _until(
            tester,
            () =>
                _universalSimilarity(tester) != null ||
                find
                    .byKey(const ValueKey('universal-error'))
                    .evaluate()
                    .isNotEmpty,
            attempts: 2400,
          );
          expect(
            find.byKey(const ValueKey('universal-error')),
            findsNothing,
            reason: '${task.id}: ${screenText(tester)}',
          );
          final dog = _universalSimilarity(tester)!;
          await tester.tap(find.byKey(const ValueKey('universal-2-elephant')));
          // The picture's own label: semantics finders read debugSemantics,
          // which release builds leave empty.
          await _until(
            tester,
            () => find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.semanticLabel == 'Image 2: Elephant',
                )
                .evaluate()
                .isNotEmpty,
          );
          await tester.tap(find.byKey(const ValueKey('universal-compare')));
          await tester.pump();
          await _until(tester, () {
            final value = _universalSimilarity(tester);
            return value != null && value != dog;
          }, attempts: 1200);
          final elephant = _universalSimilarity(tester)!;
          expect(
            elephant,
            lessThan(dog),
            reason:
                '${task.id}: dog text vs dog photo $dog, vs elephant $elephant',
          );
          checks.add('${task.id}:cpu:compare');
          break;
        case GalleryDemo.retrieve:
          // The puppy query over the page's six documents: Google's Python
          // API ranks the dog document first (0.82), the cat second.
          await tester.tap(find.byKey(const ValueKey('retrieval-search')));
          await tester.pump();
          // The first search downloads Google's 388 MB model.
          await _until(
            tester,
            () =>
                find.byKey(retrievalTopKey).evaluate().isNotEmpty ||
                find.text('Error').evaluate().isNotEmpty,
            attempts: 2400,
          );
          expect(
            find.text('Error'),
            findsNothing,
            reason: '${task.id}: ${screenText(tester)}',
          );
          final top = tester.widget<Text>(find.byKey(retrievalTopKey));
          expect(
            top.data,
            retrievalSampleDocuments.first,
            reason: '${task.id}: ${screenText(tester)}',
          );
          checks.add('${task.id}:cpu:search');
          break;
        case GalleryDemo.audio:
          checks.add('${task.id}:cpu:run');
          await _until(
            tester,
            () => find.textContaining('Done in').evaluate().isNotEmpty,
          );
          expect(find.text('Speech'), findsWidgets);
          // The microphone mode, on the speech sample as it plays: Google's
          // stream frames it into windows 975 ms apart, from the first block.
          await tester.tap(
            find.byKey(const ValueKey('audio-source-microphone')),
          );
          await _until(tester, () => _audioWindows(tester).length >= 4);
          final windows = _audioWindows(tester);
          final starts = windows.values.toList()..sort();
          expect(starts.take(4), [0, 975, 1950, 2925], reason: task.id);
          final first = windows.entries.firstWhere((e) => e.value == 0).key;
          expect(
            find.descendant(
              of: find.byKey(ValueKey('audio-scores-$first')),
              matching: find.text('Speech'),
            ),
            findsOneWidget,
            reason: '${task.id}: the first window hears speech',
          );
          checks.add('${task.id}:cpu:stream');
          // Leaving the mode flushes the stream; the clip plays again.
          await tester.tap(find.byKey(const ValueKey('audio-source-clips')));
          await _until(
            tester,
            () => find.textContaining('Done in').evaluate().isNotEmpty,
          );
          expect(find.text('Speech'), findsWidgets);
          break;
        case GalleryDemo.segment:
          final canvas = find.byKey(const ValueKey('segment-canvas'));
          await _until(tester, () => canvas.evaluate().isNotEmpty);
          expect(
            canvas,
            findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .whereType<String>()
                .join(' | '),
          );
          await tester.ensureVisible(canvas);
          await tester.tap(canvas);
          for (final (index, delegate) in delegatesFor(task).indexed) {
            if (index > 0) {
              // Switching reopens the task, so the image is tapped again.
              await tapDelegate(tester, delegate);
              await _until(tester, () => canvas.evaluate().isNotEmpty);
              await settle(tester);
              await tester.tap(canvas);
            }
            final label = delegate == Delegate.gpu ? 'GPU' : 'CPU';
            await _until(
              tester,
              () => _status(tester).any(
                (status) =>
                    status.delegate == label &&
                    status.parts.any(RegExp(r'^\d+ requests$').hasMatch),
              ),
            );
            checks.add('${task.id}:${delegate.name}:tap');
          }
          // Exclude and Lasso through the page: a drag with each brush,
          // counted on the Selection card and segmented. Controls are
          // scrolled into view before each gesture, since a tap that lands
          // elsewhere fails this test.
          final brushControl = find.byWidgetPredicate(
            (widget) => widget is Segmented<BrushMode>,
          );
          Future<void> pickBrush(String name) async {
            await _until(
              tester,
              () =>
                  brushControl.evaluate().isNotEmpty &&
                  tester.widget<Segmented<BrushMode>>(brushControl).onChanged !=
                      null,
            );
            final segment = find.byKey(ValueKey('brush-$name'));
            await tester.ensureVisible(segment);
            await tester.tap(segment);
            await tester.pump();
            await tester.ensureVisible(canvas);
            await settle(tester);
          }

          int requests() {
            var count = 0;
            for (final status in _status(tester)) {
              for (final part in status.parts) {
                final match = RegExp(r'^(\d+) requests$').firstMatch(part);
                if (match != null) count = int.parse(match.group(1)!);
              }
            }
            return count;
          }

          var before = requests();
          await pickBrush('negative');
          var size = tester.getSize(canvas);
          await tester.timedDrag(
            canvas,
            Offset(size.width * 0.2, 0),
            const Duration(milliseconds: 400),
          );
          await _until(
            tester,
            () =>
                requests() > before &&
                find.text('1 include · 1 exclude').evaluate().isNotEmpty,
          );
          checks.add('${task.id}:exclude');
          before = requests();
          await pickBrush('lasso');
          size = tester.getSize(canvas);
          final center = tester.getCenter(canvas);
          final lasso = await tester.startGesture(
            center + Offset(-size.width * 0.2, -size.height * 0.2),
          );
          for (final corner in [
            Offset(size.width * 0.2, -size.height * 0.2),
            Offset(size.width * 0.2, size.height * 0.2),
            Offset(-size.width * 0.2, size.height * 0.2),
          ]) {
            await lasso.moveTo(center + corner);
            await tester.pump(const Duration(milliseconds: 50));
          }
          await lasso.up();
          await _until(
            tester,
            () =>
                requests() > before &&
                find
                    .text('1 include · 1 exclude · 1 lasso')
                    .evaluate()
                    .isNotEmpty,
          );
          checks.add('${task.id}:lasso');
          await pickBrush('positive');
          // Undo drops the last stroke; Clear drops the rest.
          FeedButton button(String tooltip) => tester.widget<FeedButton>(
            find.byWidgetPredicate(
              (widget) => widget is FeedButton && widget.tooltip == tooltip,
            ),
          );
          await _until(tester, () => button('Undo stroke').onPressed != null);
          await tester.tap(find.byTooltip('Undo stroke'));
          await _until(
            tester,
            () => find.text('1 include · 1 exclude').evaluate().isNotEmpty,
          );
          await tester.tap(find.byTooltip('Clear selection'));
          await _until(
            tester,
            () =>
                button('Undo stroke').onPressed == null &&
                button('Clear selection').onPressed == null,
          );
          checks.add('${task.id}:undo-clear');
          break;
        case GalleryDemo.none:
          fail('${task.id} has no page');
      }
      visited.add(task.id);
    }
    expect(visited, hasLength(tasks.length));
    // ignore: avoid_print
    print('GALLERY_JOURNEY ${visited.join(',')}');
    // ignore: avoid_print
    print('GALLERY_JOURNEY_CHECKS ${checks.join(',')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// The audio page's windows: each entry's position in the list, newest
/// first, and its start in the stream in milliseconds ("0.975 s").
Map<int, int> _audioWindows(WidgetTester tester) {
  final windows = <int, int>{};
  for (var i = 0; ; i++) {
    final entry = find.byKey(ValueKey('audio-window-$i'));
    if (entry.evaluate().isEmpty) return windows;
    final text = tester.widget<Text>(entry).data!;
    windows[i] = (double.parse(text.replaceAll(' s', '')) * 1000).round();
  }
}

/// The platform's decoder reads both bundled clips frame by frame with the
/// files' own timestamps, and a file's rotation reaches the task: the rotated
/// clip's face is found only when its frames are turned upright.
Future<void> _videoFiles(GalleryAssets assets) async {
  final scene = await VideoFileReader.open(assets.path('scene.mp4'));
  final sizes = <(int, int)>{};
  final timestamps = <int>[];
  try {
    for (var frame = await scene.next(); frame != null;) {
      sizes.add((frame.width, frame.height));
      timestamps.add(frame.timestampMicroseconds);
      discardFrame(frame);
      frame = await scene.next();
    }
  } finally {
    await scene.close();
  }
  final rotated = await VideoFileReader.open(assets.path('rotated.mp4'));
  // Everything this platform's decoder reported, in its log, before the
  // first check can stop the test.
  debugPrint(
    'VIDEO_FILES scene.mp4: rotation ${scene.rotationDegrees}, sizes $sizes, '
    '${timestamps.length} frames from ${timestamps.take(3).toList()} us; '
    'rotated.mp4: rotation ${rotated.rotationDegrees}',
  );
  expect(scene.rotationDegrees, 0);
  expect(sizes, {(960, 540)});
  expect(timestamps, hasLength(_clipFrames));
  for (var i = 0; i < timestamps.length; i++) {
    // 30 frames a second, to the microsecond of each decoder's rounding.
    expect((timestamps[i] - i * 1000000 / 30).abs(), lessThan(1000));
  }
  expect(rotated.rotationDegrees, 90);
  final detector = await FaceDetector.create(
    FaceDetectorOptions(
      model: VisionModels.faceDetector,
      runningMode: RunningMode.video,
    ),
  );
  var faces = 0, frames = 0;
  try {
    for (var frame = await rotated.next(); frame != null;) {
      final prepared = await prepareFrame(frame);
      prepared.picture.dispose();
      final result = await detector.detectForVideo(
        prepared.input,
        timestampMilliseconds: (frame.timestampMicroseconds / 1000).round(),
        rotationDegrees: rotated.rotationDegrees,
      );
      frames++;
      faces += result.detections.length;
      frame = await rotated.next();
    }
  } finally {
    await rotated.close();
    await detector.dispose();
  }
  expect(frames, 10);
  expect(faces, frames, reason: 'one face in every upright frame');
}

/// A still image result that proves inference found something, not merely
/// that it finished: "0 faces detected" or "No pose detected" fail.
final _stillResults = <String, RegExp>{
  'face_detector': RegExp(r'^[1-9]\d* faces? detected$'),
  'face_landmarker': RegExp(r'^[1-9]\d* faces? detected$'),
  'gesture_recognizer': RegExp(r'^[1-9]\d* hands? recognized$'),
  'hand_landmarker': RegExp(r'^[1-9]\d* hands? detected$'),
  'holistic_landmarker': RegExp(r'^Body landmarks detected$'),
  'image_classifier': RegExp(r'^[1-9]\d* classes returned$'),
  'image_segmenter': RegExp(r'^Segmentation complete$'),
  'object_detector': RegExp(r'^[1-9]\d* objects? detected$'),
  'pose_landmarker': RegExp(r'^[1-9]\d* poses? detected$'),
};

/// The category each text page's sample belongs to. It must score at least
/// 0.5, so a run that lists it among weak results fails.
const _textCategories = <String, String>{
  'language_detector': 'fr',
  'text_classifier': 'positive',
};

/// The embedders compare two texts.
const _comparingTasks = {'text_embedder', 'embedding_gemma'};

/// What Decision Maker answers the page's sample, as Google's Python API does
/// with Laya: a refund, about shipping, and unhappy (1.28 of 0 to 4). The
/// score allows for another desktop's build of Google's library.
final _decisionAnswers = <(DecisionKind, void Function(String, String))>[
  (DecisionKind.boolean, (answer, why) => expect(answer, 'Yes', reason: why)),
  (
    DecisionKind.choice,
    (answer, why) => expect(answer, 'shipping', reason: why),
  ),
  (
    DecisionKind.score,
    (answer, why) =>
        expect(double.parse(answer), closeTo(1.28, 0.05), reason: why),
  ),
];

/// Universal Embedder's similarity on screen, or null before the first
/// comparison finishes.
double? _universalSimilarity(WidgetTester tester) {
  final finder = find.byKey(universalSimilarityKey);
  if (finder.evaluate().isEmpty) return null;
  return double.tryParse(tester.widget<Text>(finder).data ?? '');
}

/// The Proofreader and Summarizer write text, checked here for arriving;
/// sdk_modern_text_test.dart compares what they write with Google's.
const _generativeTasks = {'text_proofreader', 'text_summarizer'};

/// Lets a drawer or menu finish animating. Unlike pumpAndSettle it gives up
/// after a few seconds, because a live camera preview never stops scheduling
/// frames.
/// Waits for a camera page to open its camera: null once frames arrive, or
/// the page's message when it has no camera or could not open one.
Future<String?> _cameraProblem(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    final view = find.byType(LiveCameraView);
    if (view.evaluate().isNotEmpty) {
      final live = tester.widget<LiveCameraView>(view);
      if (live.controller.running && live.controller.recentFrames > 0) {
        return null;
      }
      if (live.placeholder case final Text message) {
        return message.data ?? 'camera error';
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  fail('The camera page neither ran nor reported a problem');
}

/// The status lines under the page's feed.
Iterable<FeedStatus> _status(WidgetTester tester) =>
    tester.widgetList<FeedStatus>(find.byType(FeedStatus));

/// Waits for the live stats line to count frames on [delegate]. An [optional]
/// delegate that errors or stays silent for a minute returns false.
Future<bool> _liveFrames(
  WidgetTester tester,
  Delegate delegate, {
  required bool optional,
}) async {
  final label = delegate == Delegate.gpu ? 'GPU' : 'CPU';
  final deadline = DateTime.now().add(Duration(seconds: optional ? 60 : 120));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    final view = find.byType(LiveCameraView);
    if (view.evaluate().isNotEmpty) {
      final controller = tester.widget<LiveCameraView>(view).controller;
      // Frames counted since the page last started on this delegate, as the
      // status line under the feed reports them.
      if (controller.running &&
          !controller.changing &&
          controller.delegate == delegate &&
          controller.recentFrames > 0 &&
          _status(tester).any((status) => status.delegate == label)) {
        return true;
      }
    }
    if (optional && view.evaluate().isNotEmpty) {
      final live = tester.widget<LiveCameraView>(view);
      if (live.controller.delegate == delegate &&
          (live.controller.error != null || live.placeholder is Text)) {
        return false;
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  if (optional) return false;
  fail('No live $label frames: ${screenText(tester)}');
}

/// Waits for a still image result from [delegate] that matches [expected]. An
/// [optional] delegate that gives none within a minute returns false.
Future<bool> _stillRan(
  WidgetTester tester,
  Delegate delegate,
  RegExp expected, {
  required bool optional,
}) async {
  final label = delegate == Delegate.gpu ? 'GPU' : 'CPU';
  final ran = RegExp(r'^Inference \d+\.\d ms$');
  final deadline = DateTime.now().add(Duration(seconds: optional ? 60 : 120));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (_status(tester).any(
      (status) =>
          status.delegate == label &&
          status.parts.any(ran.hasMatch) &&
          status.parts.any(expected.hasMatch),
    )) {
      return true;
    }
    final error = _imageError(tester);
    if (error != null) {
      if (optional) return false;
      fail('$label still image failed: $error');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  if (optional) return false;
  fail(
    'No $label still image result matching $expected: ${screenText(tester)}',
  );
}

/// Frames in the bundled clip, gallery/samples/scene.mp4.
const _clipFrames = 90;

/// Waits for the video file mode to finish the bundled clip: every frame run
/// once, in order, each result carrying its frame's timestamp, nothing
/// skipped. Returns the delegate's name.
Future<String> _videoRan(WidgetTester tester, String id) async {
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    for (final status in _status(tester)) {
      if (!status.parts.contains('scene.mp4')) continue;
      expect(
        status.parts.where(
          (part) => part.contains('out of step') || part.contains('repeated'),
        ),
        isEmpty,
        reason: id,
      );
      if (status.parts.contains('$_clipFrames frames done')) {
        // The time per frame, in every platform's log.
        debugPrint(
          '$id video file: ${status.parts.join(' · ')} · '
          '${status.delegate}',
        );
        return status.delegate!.toLowerCase();
      }
      final done = status.parts.where(
        (part) => RegExp(r'^\d+ frames? done$').hasMatch(part),
      );
      if (done.isNotEmpty) fail('$id: ${done.single}, not $_clipFrames');
    }
    final error = _imageError(tester);
    if (error != null) fail('$id video file failed: $error');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  fail('$id: the video file did not finish: ${screenText(tester)}');
}

/// The cosine similarity Image Embedder shows, once it has one.
String? _similarity(WidgetTester tester) {
  final card = find.byKey(const ValueKey('image-embedder-similarity'));
  if (card.evaluate().isEmpty) return null;
  final value = RegExp(r'^-?\d\.\d{4}$');
  for (final text in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  )) {
    if (value.hasMatch(text.data ?? '')) return text.data;
  }
  return null;
}

/// Waits for Image Embedder to compare its images on [delegate] and returns
/// the similarity. An [optional] delegate that gives none within a minute
/// returns null.
Future<String?> _compared(
  WidgetTester tester,
  Delegate delegate, {
  required bool optional,
}) async {
  final label = delegate == Delegate.gpu ? 'GPU' : 'CPU';
  final ran = RegExp(r'^Inference \d+\.\d ms$');
  final error = find.byKey(const ValueKey('image-embedder-error'));
  final deadline = DateTime.now().add(Duration(seconds: optional ? 60 : 120));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    final page = find.byType(EmbedPage);
    final busy =
        page.evaluate().isNotEmpty &&
        find
            .descendant(
              of: find.byKey(const ValueKey('image-embedder-similarity')),
              matching: find.byType(AnimatedOpacity),
            )
            .evaluate()
            .any((element) => (element.widget as AnimatedOpacity).opacity < 1);
    if (!busy &&
        _status(tester).any(
          (status) =>
              status.delegate == label && status.parts.any(ran.hasMatch),
        )) {
      if (_similarity(tester) case final similarity?) return similarity;
    }
    if (error.evaluate().isNotEmpty) {
      if (optional) return null;
      fail('$label comparison failed: ${screenText(tester)}');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  if (optional) return null;
  fail('No $label comparison: ${screenText(tester)}');
}

/// The error a still image page shows in the theme's error colour, if any.
String? _imageError(WidgetTester tester) {
  final page = find.byType(LivePage);
  if (page.evaluate().isEmpty) return null;
  final color = Theme.of(tester.element(page)).colorScheme.error;
  for (final text in tester.widgetList<Text>(
    find.descendant(of: page, matching: find.byType(Text)),
  )) {
    if (text.style?.color == color && (text.data ?? '').isNotEmpty) {
      return text.data;
    }
  }
  return null;
}

/// Every text on screen, for failure messages and notes.
void _note(String message) {
  // ignore: avoid_print
  print('GALLERY_JOURNEY_NOTE $message');
}

/// Hungry Fish's decisions so far and how many matched the scene.
(int, int) _fishScore(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(fishScoreKey)).data!;
  final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m[0]!));
  return (numbers.first, numbers.last);
}

/// Pumps until [done], for [attempts] quarter seconds: two minutes unless a
/// page says otherwise.
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  int attempts = 480,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump();
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  fail('Gallery action timed out: ${screenText(tester)}');
}
