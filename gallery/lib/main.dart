import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:file_selector/file_selector.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'catalog.dart';
import 'decision_page.dart';
import 'retrieval_page.dart';
import 'universal_embedder_page.dart';
import 'fish_game_page.dart';
import 'embed_page.dart';
import 'segment_page.dart';
import 'text_page.dart';
import 'audio/microphone.dart';
import 'audio_page.dart';
import 'live_page.dart';
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';
import 'web/model_cache.dart';
import 'web/test_hooks.dart';
import 'gallery_assets_io.dart'
    if (dart.library.js_interop) 'web/gallery_assets.dart';
export 'gallery_assets_io.dart'
    if (dart.library.js_interop) 'web/gallery_assets.dart';

SemanticsHandle? _webSemantics;

/// The gallery's task order within each category; other tasks follow by title.
const _taskOrder = [
  'face_detector',
  'face_landmarker',
  'hand_landmarker',
  'gesture_recognizer',
  'pose_landmarker',
  'holistic_landmarker',
  'object_detector',
  'image_classifier',
  'image_embedder',
  'image_segmenter',
  'interactive_segmenter',
  'audio_classifier',
  'language_detector',
  'text_classifier',
  'text_embedder',
  'decision_maker',
  'universal_embedder',
  'semantic_retriever',
];

int compareTasks(
  ({String runtimeId, String title}) a,
  ({String runtimeId, String title}) b,
) {
  int rank(String id) {
    final index = _taskOrder.indexOf(id);
    return index < 0 ? _taskOrder.length : index;
  }

  final byRank = rank(a.runtimeId).compareTo(rank(b.runtimeId));
  return byRank != 0 ? byRank : a.title.compareTo(b.title);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter keeps a DOM element per semantics node and moves them on every
  // scroll frame, which a phone's browser feels; a screen reader there can
  // still turn them on with Flutter's own accessibility button. Desktop
  // browsers keep them, as does `?test-hooks`: the browser tests find
  // controls by role.
  final phone =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  if (kIsWeb && (!phone || testHooks)) {
    _webSemantics ??= WidgetsBinding.instance.ensureSemantics();
  }
  // The browser tests have no microphone outside Chromium, so their page
  // plays the speech sample through the same microphone path instead.
  runApp(
    GalleryApp(
      microphone: Uri.base.queryParameters['microphone'] == 'sample'
          ? sampleMicrophone()
          : null,
    ),
  );
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, this.stillImagePicker, this.microphone});

  /// Lets device tests choose a fixture through the real gallery controls.
  final Future<XFile?> Function()? stillImagePicker;

  /// Lets device tests play a fixture as the audio page's microphone.
  final MicrophoneSource? microphone;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediaPipe Flutter Gallery',
    debugShowCheckedModeBanner: false,
    theme: galleryTheme(Brightness.light),
    themeMode: ThemeMode.light,
    home: HomePage(stillImagePicker: stillImagePicker, microphone: microphone),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.stillImagePicker, this.microphone});

  final Future<XFile?> Function()? stillImagePicker;
  final MicrophoneSource? microphone;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<(GalleryAssets, TaskPlatform)> _ready = _load();

  // Every capability query carries the platform snapshot it was evaluated
  // against, so the gallery reads it from the package rather than deriving a
  // second opinion about what it is running on.
  Future<(GalleryAssets, TaskPlatform)> _load() async => (
    await GalleryAssets.unpack(),
    (await queryObjectDetectorCapabilities()).platform,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<(GalleryAssets, TaskPlatform)>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.error_outline,
            text: 'Could not load the gallery.\n${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (assets, platform) = snapshot.requireData;
        final bundled = assets.bundledTasks;
        final tasks = [
          for (final task in supportedTasks(platform, bundled))
            if (task.hasOwnPage) task,
        ];
        return _GalleryShell(
          assets: assets,
          platform: platform,
          tasks: tasks,
          stillImagePicker: widget.stillImagePicker,
          microphone: widget.microphone,
        );
      },
    ),
  );
}

/// The sidebar stays in view on wide windows and opens as a drawer below
/// the design's 1200 px breakpoint.
class _GalleryShell extends StatefulWidget {
  const _GalleryShell({
    required this.assets,
    required this.platform,
    required this.tasks,
    this.stillImagePicker,
    this.microphone,
  });

  final GalleryAssets assets;
  final TaskPlatform platform;
  final List<GalleryTask> tasks;
  final Future<XFile?> Function()? stillImagePicker;
  final MicrophoneSource? microphone;

  @override
  State<_GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<_GalleryShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _navigationOpen = ValueNotifier(false);
  GalleryTask? _selectedTask;
  Timer? _prefetch;

  @override
  void dispose() {
    _prefetch?.cancel();
    _navigationOpen.dispose();
    super.dispose();
  }

  void _select(GalleryTask? task) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    if (_selectedTask?.id != task?.id) setState(() => _selectedTask = task);
    if (kIsWeb && task != null) _prefetchNeighbours(task);
  }

  /// Most visitors step through the sidebar in order, so once a camera task
  /// has had time to load its own model, the web gallery fetches the models
  /// of the camera tasks either side of it.
  void _prefetchNeighbours(GalleryTask task) {
    _prefetch?.cancel();
    final live =
        [
          for (final t in widget.tasks)
            if (t.demo == GalleryDemo.live) t,
        ]..sort(
          (a, b) => compareTasks(
            (runtimeId: a.runtimeId, title: a.title),
            (runtimeId: b.runtimeId, title: b.title),
          ),
        );
    final index = live.indexWhere((t) => t.id == task.id);
    if (index < 0) return;
    _prefetch = Timer(const Duration(seconds: 2), () {
      WebModelCache.prefetch([
        for (final i in [index + 1, index - 1])
          if (i >= 0 && i < live.length) live[i].model,
      ]);
    });
  }

  Widget _page(bool wide) {
    final task = _selectedTask;
    final openMenu = wide
        ? null
        : () {
            _navigationOpen.value = true;
            _scaffoldKey.currentState?.openDrawer();
          };
    if (task == null) {
      return _Gallery(
        assets: widget.assets,
        platform: widget.platform,
        tasks: widget.tasks,
        onTaskSelected: _select,
        onOpenMenu: openMenu,
      );
    }
    return switch (task.demo) {
      GalleryDemo.live => LivePage(
        task: task,
        navigationOpen: _navigationOpen,
        stillImagePicker: widget.stillImagePicker,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.segment => SegmentPage(
        task: task,
        assets: widget.assets,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.embed => EmbedPage(
        task: task,
        imagePicker: widget.stillImagePicker,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.text => TextPage(task: task, onOpenMenu: openMenu),
      GalleryDemo.decision => DecisionPage(
        task: task,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.game => FishGamePage(
        task: task,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.universalEmbed => UniversalEmbedderPage(
        task: task,
        imagePicker: widget.stillImagePicker,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.retrieve => RetrievalPage(
        task: task,
        platform: widget.platform,
        onOpenMenu: openMenu,
      ),
      GalleryDemo.audio => AudioPage(
        task: task,
        onOpenMenu: openMenu,
        microphone: widget.microphone,
      ),
      GalleryDemo.none => throw StateError('${task.id} has no demo'),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= Sizes.wide;
      final sidebar = _NavigationSidebar(
        tasks: widget.tasks,
        selectedTask: _selectedTask,
        onSelect: _select,
        onClose: wide ? null : () => _scaffoldKey.currentState?.closeDrawer(),
      );
      final contentWidth = constraints.maxWidth - (wide ? Sizes.sidebar : 0);
      final content = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: Size(contentWidth, MediaQuery.sizeOf(context).height)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 90),
          // Drop the outgoing task immediately so its camera and worker can
          // close before another task starts. Only the new page fades in.
          layoutBuilder: (currentChild, previousChildren) =>
              currentChild ?? const SizedBox.shrink(),
          child: KeyedSubtree(
            key: ValueKey(_selectedTask?.id ?? 'home'),
            child: _page(wide),
          ),
        ),
      );
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: GalleryColors.of(context).bg,
        drawer: wide ? null : Drawer(child: sidebar),
        onDrawerChanged: (open) => _navigationOpen.value = open,
        body: Row(
          children: [
            if (wide) SizedBox(width: Sizes.sidebar, child: sidebar),
            Expanded(key: const ValueKey('gallery-content'), child: content),
          ],
        ),
      );
    },
  );
}

class _NavigationSidebar extends StatelessWidget {
  const _NavigationSidebar({
    required this.tasks,
    required this.selectedTask,
    required this.onSelect,
    this.onClose,
  });

  final List<GalleryTask> tasks;
  final GalleryTask? selectedTask;
  final ValueChanged<GalleryTask?> onSelect;

  /// Closes the drawer; null while the sidebar stays in view.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final sorted = [...tasks]
      ..sort(
        (a, b) => compareTasks(
          (runtimeId: a.runtimeId, title: a.title),
          (runtimeId: b.runtimeId, title: b.title),
        ),
      );
    return Material(
      color: c.surface,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The design's header is 36 px with 24 of it below the
                // brand, so the brand sits centred on the top 12.
                SizedBox(
                  height: 12,
                  child: OverflowBox(
                    maxHeight: 36,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 23,
                            height: 23,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'M',
                              style: TextStyle(
                                color: c.onTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'MediaPipe Flutter Gallery',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w600,
                                fontSize: Sizes.md,
                                letterSpacing: Sizes.md * -0.02,
                              ),
                            ),
                          ),
                          if (onClose != null)
                            OutlineButton(
                              icon: LucideIcons.x,
                              tooltip: 'Close navigation',
                              onPressed: onClose,
                              bordered: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    key: const ValueKey('gallery-sidebar'),
                    padding: const EdgeInsets.only(top: 10, bottom: 24),
                    children: [
                      _item(
                        context,
                        'Home',
                        selectedTask == null,
                        () => onSelect(null),
                      ),
                      for (final category in GalleryCategory.values)
                        if (sorted.any(
                          (task) => task.category == category,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 22, 12, 6),
                            child: Text(
                              category.title,
                              style: eyebrowStyle(context),
                            ),
                          ),
                          for (final task in sorted)
                            if (task.category == category)
                              _item(
                                context,
                                task.title,
                                selectedTask?.id == task.id,
                                () => onSelect(task),
                              ),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    final c = GalleryColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        container: true,
        link: true,
        label: title,
        selected: selected,
        onTap: onTap,
        child: ExcludeSemantics(
          child: _HoverFill(
            onTap: onTap,
            builder: (hovered) => Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: selected || hovered ? c.surface2 : null,
                borderRadius: BorderRadius.circular(Sizes.radiusSmall),
                border: selected
                    ? Border(left: BorderSide(color: c.teal, width: 2))
                    : null,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected || hovered ? c.text : c.muted,
                  fontSize: Sizes.sm,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tracks the pointer over a tappable area, for the design's hover states.
class _HoverFill extends StatefulWidget {
  const _HoverFill({required this.builder, required this.onTap});

  final Widget Function(bool hovered) builder;
  final VoidCallback? onTap;

  @override
  State<_HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<_HoverFill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: widget.builder(_hovered),
    ),
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.assets,
    required this.platform,
    required this.tasks,
    required this.onTaskSelected,
    required this.onOpenMenu,
  });

  final GalleryAssets assets;
  final TaskPlatform platform;
  final List<GalleryTask> tasks;
  final ValueChanged<GalleryTask> onTaskSelected;
  final VoidCallback? onOpenMenu;

  bool _gpu(GalleryTask task) =>
      task.capabilities(platform).supportedDelegates.contains(Delegate.gpu);

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < Sizes.compact;
    final sorted = [...tasks]
      ..sort(
        (a, b) => compareTasks(
          (runtimeId: a.runtimeId, title: a.title),
          (runtimeId: b.runtimeId, title: b.title),
        ),
      );
    List<PlannedTask> plannedIn(GalleryCategory category) => [
      for (final task in plannedTasks)
        if (task.category == category &&
            !sorted.any((t) => t.title == task.title))
          task,
    ];
    final sections = [
      for (final category in GalleryCategory.values)
        if (sorted.any((task) => task.category == category) ||
            plannedIn(category).isNotEmpty)
          category,
    ];
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          if (onOpenMenu != null)
            TopBar(title: 'MediaPipe Flutter Gallery', onOpenMenu: onOpenMenu),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  // The home page has no settings column, so its cards use
                  // the whole width.
                  child: GalleryPageBody(
                    key: const ValueKey('gallery-home'),
                    maxWidth: double.infinity,
                    children: [
                      PageHeading(title: 'MediaPipe Flutter Gallery'),
                      SizedBox(height: phone ? 32 : 44),
                      if (sorted.every(
                        (t) => t.category != GalleryCategory.vision,
                      ))
                        const _Message(
                          icon: Icons.inbox_outlined,
                          text:
                              'No task has a validated runtime on this platform yet.',
                        ),
                      for (final (i, category) in sections.indexed) ...[
                        if (i > 0) const SizedBox(height: 40),
                        _SectionHeading(title: category.title),
                        _Grid(
                          phone: phone,
                          children: [
                            for (final task in sorted)
                              if (task.category == category)
                                _TaskCard(
                                  key: ValueKey('gallery-card-${task.title}'),
                                  title: task.title,
                                  summary: task.summary,
                                  gpu: _gpu(task),
                                  onTap: () => onTaskSelected(task),
                                ),
                            for (final task in plannedIn(category))
                              _TaskCard(
                                title: task.title,
                                summary: plannedReason(
                                  task,
                                  platform,
                                  assets.bundledTasks,
                                ),
                                gpu: false,
                                onTap: null,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Text(
        title,
        style: TextStyle(color: c.text, fontSize: Sizes.lg),
      ),
    );
  }
}

/// Two columns of cards, one on phones, each row as tall as its tallest.
class _Grid extends StatelessWidget {
  const _Grid({required this.phone, required this.children});

  final bool phone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (phone) {
      return Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            child,
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.title,
    required this.summary,
    required this.gpu,
    required this.onTap,
  });

  final String title;
  final String summary;
  final bool gpu;

  /// Null for a task this build does not bundle.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final phone = MediaQuery.sizeOf(context).width < Sizes.compact;
    final card = _HoverFill(
      onTap: onTap,
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, hovered ? -1 : 0, 0),
        constraints: BoxConstraints(minHeight: phone ? 104 : 116),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: hovered ? c.hoverLine : c.line),
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: Sizes.md,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: TextStyle(
                      color: c.muted,
                      fontSize: Sizes.sm,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Tag('CPU'),
                      if (gpu) ...[
                        const SizedBox(width: 5),
                        const Tag('GPU', accent: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // The card reads as one button, title first.
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '$title. $summary',
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null ? Opacity(opacity: 0.4, child: card) : card,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
