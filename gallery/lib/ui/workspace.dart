import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/link.dart';

import '../catalog.dart';
import 'components.dart';
import 'design.dart';

/// A page whose settings, which a phone shows in a sheet on a route of its
/// own, redraw with the page: [revision] changes on every [setState].
mixin RevisionedState<T extends StatefulWidget> on State<T> {
  /// Bumped on every rebuild [bumpsRevision] admits.
  final revision = ValueNotifier<int>(0);

  /// Whether a rebuild redraws the settings too.
  bool get bumpsRevision => true;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (bumpsRevision) revision.value++;
  }

  @override
  void dispose() {
    revision.dispose();
    super.dispose();
  }
}

/// The design's top bar, shown while the sidebar is hidden: the menu, the
/// page's title, and the settings button on phones.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.onOpenMenu,
    this.onOpenSettings,
  });

  final String title;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Material(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: onOpenMenu == null
                    ? null
                    : OutlineButton(
                        icon: LucideIcons.menu,
                        tooltip: 'Open navigation',
                        onPressed: onOpenMenu,
                        bordered: false,
                      ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: Sizes.md,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: onOpenSettings == null
                    ? null
                    : OutlineButton(
                        icon: LucideIcons.settings2,
                        tooltip: 'Settings',
                        onPressed: onOpenSettings,
                        bordered: false,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The settings column: its sections, under a Close button in a phone's
/// sheet.
class SettingsColumn extends StatelessWidget {
  const SettingsColumn({super.key, required this.child, this.onClose});

  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 32),
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.centerRight,
            child: OutlineButton(
              icon: LucideIcons.x,
              tooltip: 'Close settings',
              onPressed: onClose,
            ),
          ),
        child,
      ],
    );
  }
}

/// A task page: its heading and body scroll in the middle, centred at the
/// design's width, with settings beside them or, on phones, in a bottom
/// sheet the top bar opens.
class TaskWorkspace extends StatefulWidget {
  const TaskWorkspace({
    super.key,
    required this.title,
    required this.onOpenMenu,
    required this.settings,
    required this.children,
    this.onSettingsSheet,
  });

  final String title;

  /// Told when the phone's settings sheet opens and closes.
  final ValueChanged<bool>? onSettingsSheet;

  /// Opens the sidebar; null while it is in view.
  final VoidCallback? onOpenMenu;

  /// Settings sections, or null for a page without settings.
  final Widget? settings;
  final List<Widget> children;

  @override
  State<TaskWorkspace> createState() => _TaskWorkspaceState();
}

class _TaskWorkspaceState extends State<TaskWorkspace> {
  /// The settings an open phone sheet shows. The sheet is a route of its own,
  /// so it follows the page through this rather than keeping the settings it
  /// opened with.
  late final _sheetSettings = ValueNotifier<Widget?>(widget.settings);

  @override
  void didUpdateWidget(TaskWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After the frame: the sheet is outside this subtree, so it cannot be
    // rebuilt while this one builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sheetSettings.value = widget.settings;
    });
  }

  @override
  void dispose() {
    _sheetSettings.dispose();
    super.dispose();
  }

  Future<void> _openSettings(BuildContext context) async {
    widget.onSettingsSheet?.call(true);
    try {
      await showSettingsSheet(context, _sheetSettings);
    } finally {
      if (mounted) widget.onSettingsSheet?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < Sizes.compact;
    final settings = widget.settings;
    final panel = !phone && settings != null;
    // A task page on a phone starts close under its top bar, leaving the
    // screen to the feed.
    final body = GalleryPageBody(phoneTop: 14, children: widget.children);
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          if (widget.onOpenMenu != null || phone)
            Builder(
              builder: (context) => TopBar(
                title: widget.title,
                onOpenMenu: widget.onOpenMenu,
                onOpenSettings: phone && settings != null
                    ? () => _openSettings(context)
                    : null,
              ),
            ),
          // The body keeps its place in the row when the panel comes and
          // goes, so crossing the phone breakpoint relays out the page
          // instead of rebuilding it and its camera view.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: body),
                if (panel)
                  Container(
                    width: Sizes.settings,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(left: BorderSide(color: c.line)),
                    ),
                    child: SafeArea(
                      left: false,
                      child: Material(
                        type: MaterialType.transparency,
                        child: SettingsColumn(child: settings),
                      ),
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

/// Opens [settings] as the design's phone bottom sheet, rebuilt whenever
/// they change.
Future<void> showSettingsSheet(
  BuildContext context,
  ValueListenable<Widget?> settings,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
  ),
  builder: (context) => ValueListenableBuilder<Widget?>(
    valueListenable: settings,
    builder: (context, settings, _) => SettingsColumn(
      onClose: () => Navigator.of(context).pop(),
      child: settings ?? const SizedBox.shrink(),
    ),
  ),
);

/// A page's scrolling body at the design's width and padding.
class GalleryPageBody extends StatelessWidget {
  const GalleryPageBody({
    super.key,
    required this.children,
    this.maxWidth = Sizes.content,
    this.phoneTop = 28,
  });

  final List<Widget> children;

  /// The widest the content grows, centred in wider windows.
  final double maxWidth;

  /// The space above the content on a phone.
  final double phoneTop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < Sizes.compact;
    // The window's own width, since the shell narrows this page's by the
    // sidebar's: below the wide breakpoint the top bar takes the space.
    final view = View.of(context);
    final tablet = view.physicalSize.width / view.devicePixelRatio < Sizes.wide;
    final padding = phone
        ? EdgeInsets.fromLTRB(16, phoneTop, 16, 52)
        : EdgeInsets.fromLTRB(44, tablet ? 36 : 48, 44, 72);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The row atop a task page: the page's own switch, if it has one, and Info.
class TaskToolbar extends StatelessWidget {
  const TaskToolbar({super.key, required this.task, this.leading});

  final GalleryTask task;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Sizes.compact;
    final lead = leading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // One row at every width: Info drops its label when the row is
          // tight, and the page's switch shrinks only on the narrowest.
          final info = OutlineButton(
            icon: LucideIcons.info,
            label: phone || constraints.maxWidth < 450 ? null : 'Info',
            tooltip: 'About this task',
            onPressed: () => showTaskInfo(context, task),
          );
          return Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: lead == null
                      ? const SizedBox.shrink()
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: lead,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              info,
            ],
          );
        },
      ),
    );
  }
}

/// The Info button's dialog: what the task does, the model it runs, and
/// Google's guide to it.
Future<void> showTaskInfo(BuildContext context, GalleryTask task) {
  final c = GalleryColors.of(context);
  final family = task.category.title.toLowerCase();
  final guide =
      'https://ai.google.dev/edge/mediapipe/solutions/$family/${task.runtimeId}';
  final label = TextStyle(color: c.muted, fontSize: Sizes.sm);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(task.title, style: TextStyle(color: c.text, fontSize: 20)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.summary,
              style: TextStyle(color: c.text, fontSize: Sizes.md, height: 1.5),
            ),
            const SizedBox(height: 18),
            const Eyebrow('Model'),
            const SizedBox(height: 6),
            Text(task.modelFile, style: label),
            const SizedBox(height: 18),
            const Eyebrow('Guide'),
            const SizedBox(height: 6),
            Link(
              uri: Uri.parse(guide),
              target: LinkTarget.blank,
              builder: (context, openLink) => InkWell(
                onTap: openLink,
                child: Text(
                  guide,
                  style: TextStyle(
                    color: c.teal,
                    fontSize: Sizes.sm,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            if (task.gemmaModel) ...[
              const SizedBox(height: 18),
              const Eyebrow('Terms'),
              const SizedBox(height: 6),
              const GemmaNotice(),
            ],
            const SizedBox(height: 18),
            Text(
              'Settings, the model and the delegate are in the settings '
              'panel. Every change rebuilds the task with it.',
              style: label.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        PrimaryButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// The notice the Gemma Terms of Use ask an app to give with a Gemma model,
/// with links to the terms and the Prohibited Use Policy they include.
class GemmaNotice extends StatelessWidget {
  const GemmaNotice({super.key});

  static final terms = Uri.parse('https://ai.google.dev/gemma/terms');
  static final policy = Uri.parse(
    'https://ai.google.dev/gemma/prohibited_use_policy',
  );

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final style = TextStyle(color: c.muted, fontSize: Sizes.xs, height: 1.5);
    Widget link(Uri uri, String text) => Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, openLink) => InkWell(
        onTap: openLink,
        child: Text(
          text,
          style: style.copyWith(
            color: c.teal,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gemma is provided under and subject to the Gemma Terms of Use, '
          'which include its Prohibited Use Policy.',
          style: style,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            link(terms, 'Gemma Terms of Use'),
            link(policy, 'Prohibited Use Policy'),
          ],
        ),
      ],
    );
  }
}
