import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/ui/design.dart';

/// WCAG 2.1's contrast ratio.
double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// Linear sRGB to CIELAB, D65.
List<double> _lab(List<double> rgb) {
  final [r, g, b] = rgb;
  double f(double t) =>
      t > 0.008856 ? pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
  final fy = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
  final fz = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// Delta E (CIE76) between [a] and [b], as seen through [vision].
double _distance(Color a, Color b, List<List<double>> vision) {
  List<double> seen(Color c) {
    final rgb = [_linear(c.r), _linear(c.g), _linear(c.b)];
    return _lab([
      for (final row in vision)
        (row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]).clamp(0.0, 1.0),
    ]);
  }

  final (la, lb) = (seen(a), seen(b));
  return sqrt(
    pow(la[0] - lb[0], 2) + pow(la[1] - lb[1], 2) + pow(la[2] - lb[2], 2),
  );
}

/// Machado, Oliveira and Fernandes (2009) at severity 1.
const _visions = {
  'typical': [
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
  ],
  'protanopia': [
    [0.152286, 1.052583, -0.204868],
    [0.114503, 0.786281, 0.099216],
    [-0.003882, -0.048116, 1.051998],
  ],
  'deuteranopia': [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881],
  ],
  'tritanopia': [
    [1.255528, -0.076749, -0.178779],
    [-0.078411, 0.930809, 0.147602],
    [0.004733, 0.691367, 0.303900],
  ],
};

void main() {
  const c = GalleryColors.light;
  final error = galleryTheme(Brightness.light).colorScheme.error;

  const aaText = 4.5;
  const aaOther = 3.0;

  final pairs = <(String, Color, Color, double)>[
    ('text on the page', c.text, c.bg, aaText),
    ('text on a filled control', c.text, c.surface2, aaText),
    ('labels on the page', c.soft, c.bg, aaText),
    ('labels on a filled control', c.soft, c.surface2, aaText),
    ('muted text on the page', c.muted, c.bg, aaText),
    ('muted text on a filled control', c.muted, c.surface2, aaText),
    ('accent text on the page', c.accentText, c.bg, aaText),
    ('accent text on a tint', c.accentText, c.accentDim, aaText),
    ('eyebrows on the page', c.eyebrow, c.bg, aaText),
    ('a button label on the accent', c.onAccent, c.accent, aaText),
    ('a button label under the pointer', c.onAccent, c.accentHover, aaText),
    ('blue section headings', c.accent, c.bg, aaText),
    ('errors on the page', error, c.bg, aaText),
    ('errors on a filled control', error, c.surface2, aaText),
    ('a field border', c.fieldLine, c.bg, aaOther),
    ('a switch that is on', c.accent, c.accentLine, aaOther),
    ('a switch that is off', c.knobOff, c.switchOff, aaOther),
    ('the CPU line on a card', c.seriesCpu, c.surface, aaOther),
    ('the GPU line on a card', c.seriesGpu, c.surface, aaOther),
    (
      'the dark CPU line on a card',
      GalleryColors.dark.seriesCpu,
      GalleryColors.dark.surface,
      aaOther,
    ),
    (
      'the dark GPU line on a card',
      GalleryColors.dark.seriesGpu,
      GalleryColors.dark.surface,
      aaOther,
    ),
  ];

  for (final (name, foreground, background, minimum) in pairs) {
    test('$name reaches $minimum to 1', () {
      expect(_contrast(foreground, background), greaterThanOrEqualTo(minimum));
    });
  }

  for (final (name, colors) in [
    ('light', GalleryColors.light),
    ('dark', GalleryColors.dark),
  ]) {
    for (final MapEntry(key: vision, value: matrix) in _visions.entries) {
      test('the $name chart lines stay apart under $vision vision', () {
        expect(
          _distance(colors.seriesCpu, colors.seriesGpu, matrix),
          greaterThanOrEqualTo(80),
        );
      });
    }
  }
}
