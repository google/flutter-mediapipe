import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/ui/design.dart';

String _hex(Color color) => color
    .toARGB32()
    .toRadixString(16)
    .padLeft(8, '0')
    .substring(2)
    .toUpperCase();

/// The declarations of the first CSS rule for [selector] in [html].
String _rule(String html, String selector) {
  final start = html.indexOf('$selector {');
  expect(start, isNot(-1), reason: '$selector has no rule');
  return html.substring(start, html.indexOf('}', start));
}

void main() {
  // The page's first paint cannot read the theme, so it repeats it.
  final html = File('web/index.html').readAsStringSync();
  const colors = GalleryColors.light;

  test('the loading screen uses the light theme', () {
    expect(_rule(html, 'html, body'), contains('#${_hex(colors.bg)}'));
    final splash = _rule(html, '#splash');
    expect(splash, contains('background: #${_hex(colors.bg)}'));
    expect(splash, contains('color: #${_hex(colors.text)}'));
    final mark = _rule(html, '#splash .mark');
    expect(mark, contains('background: #${_hex(colors.accent)}'));
    expect(mark, contains('color: #${_hex(colors.onAccent)}'));
    expect(
      _rule(html, '#splash .bar'),
      contains('background: #${_hex(colors.accentLine)}'),
    );
    expect(
      _rule(html, '#splash .bar::after'),
      contains('background: #${_hex(colors.accent)}'),
    );
    expect(
      _rule(html, '#splash .note'),
      contains('color: #${_hex(colors.muted)}'),
    );
  });

  test('the loading screen fetches nothing itself', () {
    expect(_rule(html, '#splash'), contains('Roboto, '));
    expect(html, isNot(contains('@font-face')));
    expect(html, isNot(contains('url(')));
    final origins = RegExp(r'''(?:src|href)="https?://''').allMatches(html);
    expect(origins, isEmpty);
  });

  test('the web manifest agrees with the theme', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['theme_color'], '#${_hex(colors.accent)}');
    expect(manifest['background_color'], '#${_hex(colors.bg)}');
  });
}
