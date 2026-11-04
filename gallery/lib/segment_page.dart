import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'catalog.dart';
import 'gallery_theme.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart';
import 'segment/editor_controller.dart';
import 'segment/mask_overlay.dart';
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// MagicTouch segmentation: drag over a subject to select it, with Google's
/// three brushes. Include and Exclude strokes mark what to add and remove;
/// a lasso selects what lies inside the box around the drag.
///
/// The editor controller and mask thresholding coalesce in-flight requests,
/// keep the task's float mask intact, and serialise stroke edits against
/// native work.
class SegmentPage extends StatefulWidget {
  const SegmentPage({
    super.key,
    required this.task,
    required this.assets,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final GalleryAssets assets;
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> with RevisionedState {
  EditorController? _editor;
  InteractiveSegmenter? _task;
  ui.Image? _maskImage;
  String? _error;
  late final _values = TaskSettingValues(widget.task.runtimeId);
  late final List<TaskSetting> _settings =
      taskSettings[widget.task.runtimeId] ?? const [];

  /// Kept off the ends, where a mask would be all or nothing.
  double get _threshold => _values.share('threshold').clamp(0.05, 0.95);

  /// The sample's width over height. The tap area takes exactly this shape,
  /// so a tap's position is measured against the picture, not the letterbox.
  double? _imageAspect;
  int _paintedRevision = -1;
  int _openRevision = 0;

  late final List<Delegate> _delegates =
      widget.task.capabilities(widget.platform).supportedDelegates.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  late Delegate _delegate = preferredDelegate(_delegates);

  @override
  void initState() {
    super.initState();
    _resolveImageAspect();
    unawaited(_open());
  }

  void _resolveImageAspect() {
    final stream = widget.assets
        .imageProvider(widget.task.sample)
        .resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      final aspect = info.image.width / info.image.height;
      info.dispose();
      if (mounted) setState(() => _imageAspect = aspect);
    });
    stream.addListener(listener);
  }

  Future<void> _open() async {
    final revision = ++_openRevision;
    try {
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(
          model: widget.task.model,
          delegate: _delegate,
        ),
      );
      // A later open (a delegate switch) or leaving the page replaces this one.
      if (!mounted || revision != _openRevision) {
        await task.dispose();
        return;
      }
      _task = task;
      final editor = EditorController(
        NativeSegmentationBackend(task),
        debugLabel: 'Segment ${_delegateName(_delegate)}',
      )..addListener(_onEditorChanged);
      _editor = editor;
      await editor.loadImage(
        VisionImage.fromFile(widget.assets.path(widget.task.sample)),
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      debugPrint('Segment ${_delegateName(_delegate)}: open failed: $error');
      if (mounted && revision == _openRevision) {
        setState(() => _error = '$error');
      }
    }
  }

  static String _delegateName(Delegate delegate) =>
      delegate == Delegate.gpu ? 'GPU' : 'CPU';

  /// Reopens the segmenter on [delegate] with the same image; strokes and the
  /// mask start over, since they belong to the task being replaced.
  Future<void> _setDelegate(Delegate delegate) async {
    if (delegate == _delegate) return;
    final editor = _editor;
    final task = _task;
    editor?.removeListener(_onEditorChanged);
    setState(() {
      _delegate = delegate;
      _editor = null;
      _task = null;
      _error = null;
      _maskImage?.dispose();
      _maskImage = null;
      _paintedRevision = -1;
    });
    await editor?.close();
    await task?.dispose();
    if (mounted) await _open();
  }

  void _onEditorChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_repaintMask());
  }

  Future<void> _repaintMask() async {
    final mask = _editor?.mask;
    if (mask == null) {
      _maskImage?.dispose();
      _maskImage = null;
      return;
    }
    // Rebuilding the image on every notification would thrash; the editor only
    // produces a new mask when a stroke completes.
    final revision = Object.hash(mask, _threshold);
    if (revision == _paintedRevision) return;
    _paintedRevision = revision;
    final rgba = maskRgba(mask.confidence, _threshold);
    final image = await _decode(rgba, mask.width, mask.height);
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _maskImage?.dispose();
      _maskImage = image;
    });
  }

  Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  void dispose() {
    _editor?.removeListener(_onEditorChanged);
    unawaited(_editor?.close());
    unawaited(_task?.dispose());
    _maskImage?.dispose();
    super.dispose();
  }

  /// A lasso shorter than the editor's minimum is dropped, so a tap does
  /// nothing in that mode. Say which gesture the selected tool expects.
  static String _hintFor(BrushMode? brush) => switch (brush) {
    BrushMode.negative => 'Tap or drag over an area to exclude it.',
    BrushMode.lasso => 'Draw a shape around a subject to select it.',
    _ => 'Tap or drag over a subject to include it.',
  };

  /// The finished strokes by brush, "1 include · 1 exclude · 1 lasso", or
  /// null before the first.
  static String? _summary(EditorController? editor) {
    final counts = editor?.strokeCounts;
    if (counts == null || counts.isEmpty) return null;
    return [
      for (final MapEntry(key: brush, value: count) in counts.entries)
        '$count ${switch (brush) {
          BrushMode.positive => 'include',
          BrushMode.negative => 'exclude',
          BrushMode.lasso => 'lasso',
        }}',
    ].join(' · ');
  }

  NormalizedKeypoint? _pointFor(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    return NormalizedKeypoint(x: x, y: y);
  }

  Widget _panel() => TaskSettingsPanel(
    settings: _settings,
    values: _values,
    delegates: _delegates,
    delegate: _delegate,
    // Until the open task is ready, so a switch never overlaps an open
    // still in flight.
    enabled: _editor?.ready ?? false,
    onChanged: (key, value) {
      setState(() => _values[key] = value);
      unawaited(_repaintMask());
    },
    onDelegate: (delegate) => unawaited(_setDelegate(delegate)),
    models: const [],
    model: null,
    uploaded: null,
    modelStatus: null,
    onModel: (_) {},
    onUpload: null,
    bundledModel: widget.task.modelFile,
  );

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final editor = _editor;
    // Opening the task or loading the picture failed: nothing to draw on.
    final error = _error ?? ((editor?.ready ?? true) ? null : editor?.error);
    // A request failed: the picture, strokes and last mask stay, and the
    // next stroke asks again.
    final failure = (editor?.ready ?? false) ? editor?.error : null;
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      // Rebuilt with the page, so the sheet shows the current values.
      settings: ListenableBuilder(
        listenable: revision,
        builder: (context, _) => _panel(),
      ),
      children: [
        TaskToolbar(task: widget.task),
        FeedFrame(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFF0F3F2)),
                    ),
                  ),
                )
              else if (editor == null || !editor.ready || _imageAspect == null)
                const Center(child: CircularProgressIndicator())
              else
                Center(
                  child: AspectRatio(
                    aspectRatio: _imageAspect!,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Semantics(
                        label: 'Segmentation image',
                        identifier: 'segment-canvas-${_delegate.name}',
                        child: GestureDetector(
                          key: const ValueKey('segment-canvas'),
                          // On web a click on a tappable semantics node
                          // arrives as a positionless tap, which put every
                          // stroke at the image centre. Real pointer events
                          // carry where the user clicked.
                          excludeFromSemantics: true,
                          onPanStart: (details) {
                            final point = _pointFor(
                              details.localPosition,
                              constraints.biggest,
                            );
                            if (point != null) editor.begin(point);
                          },
                          onPanUpdate: (details) {
                            final point = _pointFor(
                              details.localPosition,
                              constraints.biggest,
                            );
                            if (point != null) editor.extend(point);
                          },
                          onPanEnd: (_) => editor.end(),
                          // A lasso needs a drag: the editor drops one
                          // shorter than its minimum, as Google's web sample
                          // does, so a tap in lasso mode is left alone.
                          onTapUp: editor.brush == BrushMode.lasso
                              ? null
                              : (details) {
                                  final point = _pointFor(
                                    details.localPosition,
                                    constraints.biggest,
                                  );
                                  if (point == null) return;
                                  editor
                                    ..begin(point)
                                    ..end();
                                },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: widget.assets.imageProvider(
                                  widget.task.sample,
                                ),
                                fit: BoxFit.contain,
                              ),
                              if (_maskImage case final image?)
                                CustomPaint(painter: _MaskPainter(image)),
                              // The finished strokes and the one being
                              // drawn, in each brush's color as Google's
                              // samples show them.
                              CustomPaint(
                                painter: _StrokePainter(
                                  completed: editor.completedStrokes,
                                  active: editor.activePoints,
                                  activeBrush: editor.activeBrush,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (failure != null)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 14,
                  child: IgnorePointer(
                    child: Semantics(
                      identifier: 'segment-failure',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xDD101715),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            'Segmentation failed: $failure\n'
                            'Draw again to retry, or clear the selection.',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFF0F3F2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Row(
                  children: [
                    FeedButton(
                      icon: LucideIcons.undo2,
                      tooltip: 'Undo stroke',
                      onPressed: editor?.canUndo ?? false
                          ? () => editor!.undo()
                          : null,
                    ),
                    const SizedBox(width: 7),
                    FeedButton(
                      icon: LucideIcons.eraser,
                      tooltip: 'Clear selection',
                      // clear() reloads the image, which drops every stroke
                      // and the mask.
                      onPressed:
                          editor != null && editor.ready && editor.canUndo
                          ? () => unawaited(editor.clear())
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        FeedStatus(
          parts: [
            if (editor?.lastInferenceMs case final ms?) ...[
              '${ms.toStringAsFixed(1)} ms',
              '${editor!.completedRequests} requests',
              '${editor.coalescedRequests} coalesced',
            ] else
              _hintFor(editor?.brush),
          ],
          delegate: _delegateName(_delegate),
        ),
        const SizedBox(height: 11),
        // The controller reads `brush` when a stroke begins, so a change
        // mid-stroke cannot alter the stroke already running.
        Segmented<BrushMode>(
          expand: true,
          semanticsIdentifier: 'segment-brush',
          segments: const [
            (
              value: BrushMode.positive,
              label: 'Include',
              icon: LucideIcons.circlePlus,
              key: ValueKey('brush-positive'),
            ),
            (
              value: BrushMode.negative,
              label: 'Exclude',
              icon: LucideIcons.circleMinus,
              key: ValueKey('brush-negative'),
            ),
            (
              value: BrushMode.lasso,
              label: 'Lasso',
              icon: LucideIcons.lasso,
              key: ValueKey('brush-lasso'),
            ),
          ],
          selected: editor?.brush ?? BrushMode.positive,
          onChanged: editor == null || !editor.ready
              ? null
              : (mode) => setState(() => editor.brush = mode),
        ),
        const SizedBox(height: 11),
        OutputCard(
          title: 'Selection',
          count: _summary(editor),
          empty: _hintFor(editor?.brush),
          child: editor?.mask == null
              ? null
              : Text(
                  'Pixels above ${_threshold.toStringAsFixed(2)} confidence '
                  'are drawn as the selection.',
                  style: TextStyle(color: c.muted, fontSize: Sizes.sm),
                ),
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.completed,
    required this.active,
    required this.activeBrush,
  });

  /// The finished strokes, normalized to the picture, which fills this
  /// painter exactly.
  final List<Stroke> completed;

  /// The stroke being drawn, and its brush.
  final List<NormalizedKeypoint> active;
  final BrushMode activeBrush;

  /// Include in the design's accent; Exclude and Lasso in the red and blue of
  /// Google's samples, the lasso filled lightly.
  static const _exclude = Color(0xFFE53935);
  static const _lasso = Color(0xFF2196F3);

  static Color _colorFor(BrushMode brush) => switch (brush) {
    BrushMode.positive => GalleryTheme.accentLight,
    BrushMode.negative => _exclude,
    BrushMode.lasso => _lasso,
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in completed) {
      _paintStroke(canvas, size, stroke.points, stroke.brushMode, done: true);
    }
    if (active.isNotEmpty) {
      _paintStroke(canvas, size, active, activeBrush, done: false);
    }
  }

  void _paintStroke(
    Canvas canvas,
    Size size,
    List<NormalizedKeypoint> points,
    BrushMode brush, {
    required bool done,
  }) {
    final color = _colorFor(brush);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = brush == BrushMode.lasso ? 3 : 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset at(NormalizedKeypoint p) =>
        Offset(p.x * size.width, p.y * size.height);
    if (points.length == 1) {
      canvas.drawCircle(at(points.first), 3, paint..style = PaintingStyle.fill);
      return;
    }
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(at(point).dx, at(point).dy);
    }
    if (brush == BrushMode.lasso) {
      // Google's samples close and fill the lasso once it has a shape.
      final fill = Path.from(path);
      if (done || points.length > 2) fill.close();
      canvas.drawPath(
        fill,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      oldDelegate.completed.length != completed.length ||
      (completed.isNotEmpty &&
          !identical(oldDelegate.completed.last, completed.last)) ||
      oldDelegate.active.length != active.length ||
      oldDelegate.activeBrush != activeBrush;
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter(this.mask);

  final ui.Image mask;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: mask,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) => oldDelegate.mask != mask;
}
