import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera_geometry.dart';

/// Google's web demo colors for Image Segmenter classes, by class index:
/// background in Google Blue, a person in cyan. Classes past the end of the
/// table are left transparent, as the demo leaves them.
const segmenterLegendColors = <Color>[
  Color.fromARGB(255, 66, 133, 244),
  Color.fromARGB(200, 128, 0, 0),
  Color.fromARGB(200, 0, 128, 0),
  Color.fromARGB(200, 128, 128, 0),
  Color.fromARGB(200, 0, 0, 128),
  Color.fromARGB(200, 128, 0, 128),
  Color.fromARGB(200, 0, 128, 128),
  Color.fromARGB(200, 128, 128, 128),
  Color.fromARGB(200, 64, 0, 0),
  Color.fromARGB(200, 0, 255, 0),
  Color.fromARGB(200, 192, 0, 0),
  Color.fromARGB(200, 255, 105, 180),
  Color.fromARGB(200, 192, 128, 0),
  Color.fromARGB(200, 64, 0, 128),
  Color.fromARGB(200, 192, 0, 128),
  Color.fromARGB(255, 0, 255, 255),
  Color.fromARGB(200, 0, 128, 0),
  Color.fromARGB(200, 128, 64, 0),
  Color.fromARGB(200, 0, 192, 0),
  Color.fromARGB(200, 128, 192, 0),
  Color.fromARGB(200, 0, 64, 128),
];

/// How a segmentation result is drawn: every class in its legend color, or
/// the confidence of one class as the opacity of Google's blue.
typedef MaskStyle = ({bool confidence, int selectedClass});

/// Turns segmentation results into mask images at the mask's full
/// resolution, one at a time, keeping only the newest result while one is
/// being built so a slow build never queues frames.
final class SegmentationMaskImages extends ChangeNotifier {
  ui.Image? _image;
  ImageSegmenterResult? _wanted;
  MaskStyle _style = (confidence: false, selectedClass: 0);
  bool _building = false;
  bool _disposed = false;

  /// The newest finished mask, laid out as the upright frame.
  ui.Image? get image => _image;

  /// Builds the mask image for [result] in [style]; null clears it.
  void show(ImageSegmenterResult? result, MaskStyle style) {
    if (identical(result, _wanted) && style == _style) return;
    _wanted = result;
    _style = style;
    if (!_building) unawaited(_build());
  }

  Future<void> _build() async {
    _building = true;
    try {
      while (true) {
        final result = _wanted;
        final style = _style;
        final pixels = result == null ? null : maskPixels(result, style);
        final image = pixels == null
            ? null
            : await _decode(pixels.rgba, pixels.width, pixels.height);
        if (_disposed) {
          image?.dispose();
          return;
        }
        _image?.dispose();
        _image = image;
        notifyListeners();
        if (identical(result, _wanted) && style == _style) return;
      }
    } finally {
      _building = false;
    }
  }

  static Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

/// The RGBA pixels of [result] drawn in [style], or null when the result
/// lacks the mask that style needs. Colors are premultiplied by their alpha,
/// as [ui.decodeImageFromPixels] reads them.
({Uint8List rgba, int width, int height})? maskPixels(
  ImageSegmenterResult result,
  MaskStyle style,
) {
  if (style.confidence) {
    final masks = result.confidenceMasks;
    if (masks == null || style.selectedClass >= masks.length) return null;
    final mask = masks[style.selectedClass];
    final confidence = mask.confidence;
    final rgba = Uint8List(confidence.length * 4);
    for (var i = 0, o = 0; i < confidence.length; i++, o += 4) {
      final alpha = (confidence[i].clamp(0.0, 1.0) * 255).round();
      rgba[o + 2] = alpha;
      rgba[o + 3] = alpha;
    }
    return (rgba: rgba, width: mask.width, height: mask.height);
  }
  final mask = result.categoryMask;
  if (mask == null) return null;
  // One word per pixel, its bytes in RGBA order on little-endian machines.
  final palette = Uint32List(256);
  for (final (i, color) in segmenterLegendColors.indexed) {
    final alpha = (color.a * 255).round();
    int channel(double value) => (value * alpha).round();
    palette[i] =
        channel(color.r) |
        channel(color.g) << 8 |
        channel(color.b) << 16 |
        alpha << 24;
  }
  final categories = mask.categories;
  final words = Uint32List(categories.length);
  for (var i = 0; i < categories.length; i++) {
    words[i] = palette[categories[i]];
  }
  return (
    rgba: words.buffer.asUint8List(),
    width: mask.width,
    height: mask.height,
  );
}

/// Paints the newest mask image over the preview, scaled with filtering so
/// its edges stay smooth, at [opacity].
///
/// Google's segmenter answers a rotated frame with the upright mask resized to
/// the frame's dimensions (upstream-issues.md UP-017), so the mask covers the
/// upright frame rather than being turned as landmarks are.
class MaskOverlay extends CustomPainter {
  MaskOverlay(this.masks, {required this.transform, required this.opacity})
    : super(repaint: masks);

  final SegmentationMaskImages masks;
  final PreviewTransform transform;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final image = masks.image;
    if (image == null || opacity <= 0) return;
    final topLeft = transform.mapUpright(0, 0);
    final bottomRight = transform.mapUpright(1, 1);
    canvas
      ..save()
      ..translate(topLeft.dx, topLeft.dy)
      // A mirrored preview gives a negative width, which flips the mask too.
      ..scale(
        (bottomRight.dx - topLeft.dx) / image.width,
        (bottomRight.dy - topLeft.dy) / image.height,
      )
      ..drawImage(
        image,
        Offset.zero,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(MaskOverlay oldDelegate) =>
      oldDelegate.masks != masks ||
      oldDelegate.transform != transform ||
      oldDelegate.opacity != opacity;
}

/// Google's legend: a color box and the label of each of the model's classes.
class SegmenterLegend extends StatelessWidget {
  const SegmenterLegend(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      key: const ValueKey('segmenter-legend'),
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (i, label) in labels.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: i < segmenterLegendColors.length
                      ? segmenterLegendColors[i]
                      : Colors.transparent,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}
