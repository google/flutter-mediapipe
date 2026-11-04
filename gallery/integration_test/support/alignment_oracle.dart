import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/camera_geometry.dart';
import 'package:mediapipe_gallery/live/face_overlay.dart';
import 'package:mediapipe_gallery/live/landmark_overlay.dart';
import 'package:mediapipe_gallery/live/live_camera_controller.dart';
import 'package:mediapipe_gallery/live/live_camera_view.dart';
import 'package:mediapipe_gallery/live/live_subjects.dart';

import 'live_subject.dart';

/// Checks that the overlay lands on the subject (a face, a hand) the viewer
/// can actually see.
///
/// The geometry unit tests prove [PreviewTransform] is consistent with the
/// rules in `camera_geometry.dart`. They cannot prove those rules match what a
/// platform's camera plugin really does to its preview, which is the only
/// thing that decides whether the dots sit on the face. This oracle closes
/// that gap without a person: it screenshots the preview with the overlay
/// hidden, runs the same official IMAGE-mode task over those on-screen pixels,
/// and compares the face it finds there with where the overlay would draw the
/// live result. A wrong rotation puts the two a quarter turn apart and a wrong
/// crop drifts them toward an edge, both by tens of percent. A wrong mirror
/// reflects the face about the frame's centre line, so it moves every probe by
/// twice the face's distance from that line (roughly 5% of the diagonal for
/// the fixture, whose face sits near the middle).
///
/// Across a mirror the IMAGE task may relabel landmarks: see
/// [AlignmentProbes.partners]. Each hypothesis is compared under the labels it
/// implies.

/// Accept this much median disagreement, as a fraction of the preview
/// diagonal, and [alignmentOutlierTolerance] for any single probe.
///
/// VIDEO tracking versus a fresh IMAGE pass over rescaled screen pixels
/// differs by a few tenths of a percent on the fixture, with the chin the
/// least stable probe (1.9% on hosted Linux). The failure modes the oracle
/// exists for move every probe together by tens of percent.
const alignmentTolerance = 0.015;
const alignmentOutlierTolerance = 0.03;

/// Decoded RGBA pixels.
typedef RgbaImage = ({Uint8List rgba, int width, int height});

/// Where the live view drew its overlay, in logical pixels, and the transform
/// it used to get there. Read from the live widget tree rather than
/// recomputed, so the test measures the real painter's geometry.
typedef OverlayGeometry = ({Rect box, PreviewTransform transform});

/// The live overlay's box and transform as currently laid out.
OverlayGeometry overlayGeometry(
  WidgetTester tester,
  LiveCameraController<Object?> controller,
) {
  PreviewTransform? transformOf(Widget widget) => switch (widget) {
    CustomPaint(painter: final FaceOverlay overlay) => overlay.transform,
    CustomPaint(painter: final LandmarkOverlay overlay) => overlay.transform,
    _ => null,
  };
  final paint = find.descendant(
    of: find.byType(LiveCameraView),
    matching: find.byWidgetPredicate((widget) => transformOf(widget) != null),
  );
  expect(paint, findsOneWidget, reason: 'the overlay must be painting');
  final box = tester.renderObject<RenderBox>(paint);
  return (
    box: box.localToGlobal(Offset.zero) & box.size,
    transform: transformOf(tester.widget(paint))!,
  );
}

/// One comparison between the live overlay and the on-screen subject.
final class AlignmentMeasurement {
  const AlignmentMeasurement({
    required this.observedSubjects,
    required this.distances,
    required this.distancesIfMirrored,
    required this.cropSize,
  });

  /// Subjects the IMAGE task found in the preview crop; the oracle needs one.
  final int observedSubjects;

  /// Probe index to distance between overlay and on-screen landmark, as a
  /// fraction of the crop diagonal.
  final Map<int, double> distances;

  /// The same distances if the overlay had been mirrored the other way, so a
  /// failure report says which hypothesis the screen actually matches.
  final Map<int, double> distancesIfMirrored;

  /// Crop size in screenshot pixels.
  final Size cropSize;

  double get median => _median(distances.values);
  double get maximum => distances.values.fold(0.0, (a, b) => math.max(a, b));
  double get medianIfMirrored => _median(distancesIfMirrored.values);

  bool get aligned =>
      observedSubjects == 1 &&
      median <= alignmentTolerance &&
      maximum <= alignmentOutlierTolerance;

  Map<String, Object?> toJson() => {
    'observed_subjects': observedSubjects,
    'crop_size': [cropSize.width, cropSize.height],
    'tolerance': alignmentTolerance,
    'outlier_tolerance': alignmentOutlierTolerance,
    'median': median,
    'maximum': maximum,
    'median_if_mirrored': medianIfMirrored,
    'aligned': aligned,
    'distances': {
      for (final entry in distances.entries) '${entry.key}': entry.value,
    },
  };

  static double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return double.nan;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

/// Decodes a PNG (or any codec Flutter supports) into raw RGBA.
Future<RgbaImage> decodeImage(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final image = (await codec.getNextFrame()).image;
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return (
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// Copies [region] out of [source]. The region is clamped to the image.
RgbaImage cropImage(RgbaImage source, Rect region) {
  final left = region.left.round().clamp(0, source.width);
  final top = region.top.round().clamp(0, source.height);
  final right = region.right.round().clamp(left, source.width);
  final bottom = region.bottom.round().clamp(top, source.height);
  final width = right - left, height = bottom - top;
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    final from = ((top + y) * source.width + left) * 4;
    out.setRange(y * width * 4, (y + 1) * width * 4, source.rgba, from);
  }
  return (rgba: out, width: width, height: height);
}

/// Bounding box of pixels within 8 of [color] in each channel, or null when
/// none match.
Rect? boundsOfColor(RgbaImage image, Color color) {
  const slack = 8;
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  final r = (color.r * 255).round(),
      g = (color.g * 255).round(),
      b = (color.b * 255).round();
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      if ((image.rgba[i] - r).abs() <= slack &&
          (image.rgba[i + 1] - g).abs() <= slack &&
          (image.rgba[i + 2] - b).abs() <= slack) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX + 1.0,
    maxY + 1.0,
  );
}

/// Runs [subject]'s official IMAGE task over the preview's screen pixels and
/// compares what it finds with where the overlay draws [live].
///
/// [previewInScreenshot] is the overlay box in screenshot pixels and
/// [pixelsPerLogical] converts the overlay's logical coordinates to it.
Future<AlignmentMeasurement> measureAlignment({
  required LiveSubject subject,
  required RgbaImage screenshot,
  required Rect previewInScreenshot,
  required double pixelsPerLogical,
  required List<LivePoint> live,
  required PreviewTransform transform,
  required Uint8List modelBytes,
}) async {
  final crop = cropImage(screenshot, previewInScreenshot);
  final found = await subject.detectImage(
    modelBytes,
    crop.rgba,
    crop.width,
    crop.height,
  );
  final size = Size(crop.width.toDouble(), crop.height.toDouble());
  if (found.isEmpty) {
    return AlignmentMeasurement(
      observedSubjects: 0,
      distances: const {},
      distancesIfMirrored: const {},
      cropSize: size,
    );
  }
  final observed = found.first;
  final probes = subject.probes;
  final diagonal = math.sqrt(
    size.width * size.width + size.height * size.height,
  );
  final mirrored = PreviewTransform(
    quarterTurns: transform.quarterTurns,
    mirror: !transform.mirror,
    uprightSize: transform.uprightSize,
    scale: transform.scale,
    offsetX: transform.offsetX,
    offsetY: transform.offsetY,
  );
  double distance(PreviewTransform hypothesis, int index) {
    final expected =
        hypothesis.map(live[index].x, live[index].y) * pixelsPerLogical;
    // A hypothesis that mirrors the preview also implies mirrored labels.
    final label = hypothesis.mirror ? probes.partners[index]! : index;
    final seen = Offset(
      observed[label].x * size.width,
      observed[label].y * size.height,
    );
    return (expected - seen).distance / diagonal;
  }

  return AlignmentMeasurement(
    observedSubjects: found.length,
    distances: {for (final i in probes.indices) i: distance(transform, i)},
    distancesIfMirrored: {
      for (final i in probes.indices) i: distance(mirrored, i),
    },
    cropSize: size,
  );
}
