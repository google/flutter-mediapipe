import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/task_models.dart';
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
        'https://developers.google.com/edge/mediapipe/solutions/vision/face_detector',
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
        'https://developers.google.com/edge/mediapipe/solutions/text/text_embedder',
      ),
    );
    Navigator.of(tester.element(find.byType(Link))).pop();
    await tester.pumpAndSettle();

    gemmaTerms = true;
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.byType(GemmaNotice), findsOneWidget);
  });

  testWidgets('Info names the model the page runs, not only its own', (
    tester,
  ) async {
    final task = supportedTasks(
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '15',
      ),
      const {'pose_landmarker'},
    ).firstWhere((task) => task.hasOwnPage);
    final heavy = taskModels['pose_landmarker']!.firstWhere(
      (model) => model.name == 'Pose Landmarker (Heavy)',
    );
    expect(heavy.file, 'pose_landmarker_heavy.task');
    expect(task.modelFile, isNot(heavy.file));
    String? chosen;
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: galleryTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TaskToolbar(task: task, model: chosen),
                TextButton(
                  onPressed: () => setState(() => chosen = heavy.file),
                  child: const Text('Choose'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text(task.modelFile), findsOneWidget);
    Navigator.of(tester.element(find.byType(Link).last)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose'));
    await tester.pump();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text(heavy.file), findsOneWidget);
    expect(find.text(task.modelFile), findsNothing);
  });

  testWidgets('a page names its chosen or uploaded model, else none', (
    tester,
  ) async {
    await tester.pumpWidget(const _Picker());
    final state = tester.state<_PickerState>(find.byType(_Picker));
    expect(state.modelFile, isNull);

    state.model = taskModels['pose_landmarker']!.first;
    expect(state.modelFile, 'pose_landmarker_full.task');

    state.uploaded = 'my_pose.task';
    expect(state.modelFile, 'my_pose.task');
  });
}

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> with ModelSelectionState {
  @override
  void modelChanged() {}

  @override
  Widget build(BuildContext context) => const SizedBox();
}
