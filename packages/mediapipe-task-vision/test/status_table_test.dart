import 'dart:io';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:test/test.dart';

// tool/VISION_TASKS_STATUS.md's Support table against the capability claims
// it restates, read with every web adapter registered, as
// coverage_matrix_test.dart reads them. A cell is ✗ where a task offers no
// delegate, the platform's GPU name where it offers the GPU, and CPU
// otherwise; its footnotes ([b], [d], ...) are kept by hand and must each be
// defined under "## Upstream limits". Run from the package folder.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'Face Detector': faceDetectorCapabilitiesForPlatform,
  'Face Landmarker': faceLandmarkerCapabilitiesForPlatform,
  'Hand Landmarker': handLandmarkerCapabilitiesForPlatform,
  'Pose Landmarker': poseLandmarkerCapabilitiesForPlatform,
  'Gesture Recognizer': gestureRecognizerCapabilitiesForPlatform,
  'Holistic Landmarker': holisticLandmarkerCapabilitiesForPlatform,
  'Object Detector': objectDetectorCapabilitiesForPlatform,
  'Image Classifier': imageClassifierCapabilitiesForPlatform,
  'Image Embedder': imageEmbedderCapabilitiesForPlatform,
  'Image Segmenter': imageSegmenterCapabilitiesForPlatform,
  'Interactive Segmenter (strokes)':
      interactiveSegmenterCapabilitiesForPlatform,
};

/// The table's columns: the platform each describes and what its GPU path is
/// called in the table.
const _columns = <String, ({TaskPlatform platform, String gpu})>{
  'Web': (
    platform: TaskPlatform(operatingSystem: 'web', architecture: 'unknown'),
    gpu: 'WebGL',
  ),
  'iOS': (
    platform: TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '15.0',
    ),
    gpu: 'Metal',
  ),
  'Android': (
    platform: TaskPlatform(operatingSystem: 'android', architecture: 'arm64'),
    gpu: 'GPU',
  ),
  'macOS': (
    platform: TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '14.0',
    ),
    gpu: 'Metal',
  ),
  'Linux': (
    platform: TaskPlatform(operatingSystem: 'linux', architecture: 'x64'),
    gpu: 'GL ES',
  ),
  'Windows': (
    platform: TaskPlatform(operatingSystem: 'windows', architecture: 'x64'),
    gpu: 'GPU',
  ),
};

final _footnote = RegExp(r'\[([a-z])\]');

Never _unused(Object? _) => throw UnimplementedError();

/// The Support table's rows by task name, each the cells by column name with
/// the footnotes removed, and the footnotes the table uses.
({Map<String, Map<String, String>> rows, Set<String> footnotes}) _supportTable(
  String document,
) {
  final lines = document.split('\n');
  final header = lines.indexWhere((line) => line.startsWith('| Task |'));
  expect(header, isNot(-1), reason: 'no "| Task |" table header');
  final columns = _cells(lines[header]).skip(1).toList();
  expect(columns, _columns.keys.toList(), reason: 'the table\'s columns');
  final rows = <String, Map<String, String>>{};
  final footnotes = <String>{};
  for (final line in lines.skip(header + 2)) {
    if (!line.startsWith('|')) break;
    final cells = _cells(line);
    expect(cells, hasLength(columns.length + 1), reason: line);
    footnotes.addAll(_footnote.allMatches(line).map((m) => m[1]!));
    rows[cells.first] = {
      for (var i = 0; i < columns.length; i++)
        columns[i]: cells[i + 1].replaceAll(_footnote, '').trim(),
    };
  }
  return (rows: rows, footnotes: footnotes);
}

List<String> _cells(String line) {
  final inner = line.trim();
  return inner
      .substring(1, inner.length - 1)
      .split('|')
      .map((cell) => cell.trim())
      .toList();
}

/// What the table should say for [claim] on [column].
String _expected(TaskCapabilities Function(TaskPlatform) claim, String column) {
  final (:platform, :gpu) = _columns[column]!;
  final delegates = claim(platform).supportedDelegates;
  if (delegates.contains(Delegate.gpu)) return gpu;
  return delegates.contains(Delegate.cpu) ? 'CPU' : '✗';
}

void main() {
  late String document;

  setUpAll(() {
    faceLandmarkerBackendFactory = _unused;
    faceDetectorBackendFactory = _unused;
    handLandmarkerBackendFactory = _unused;
    poseLandmarkerBackendFactory = _unused;
    gestureRecognizerBackendFactory = _unused;
    holisticLandmarkerBackendFactory = _unused;
    objectDetectorBackendFactory = _unused;
    imageClassifierBackendFactory = _unused;
    imageEmbedderBackendFactory = _unused;
    imageSegmenterBackendFactory = _unused;
    interactiveSegmenterBackendFactory = _unused;
    document = File('tool/VISION_TASKS_STATUS.md').readAsStringSync();
  });

  test('the Support table lists every task once', () {
    final (:rows, footnotes: _) = _supportTable(document);
    expect(rows.keys.toSet(), _claims.keys.toSet());
  });

  test('every Support cell restates the capability claims', () {
    final (:rows, footnotes: _) = _supportTable(document);
    final problems = <String>[];
    for (final MapEntry(key: task, value: claim) in _claims.entries) {
      final cells = rows[task];
      if (cells == null) continue;
      for (final column in _columns.keys) {
        final expected = _expected(claim, column);
        if (cells[column] != expected) {
          problems.add(
            '$task / $column says "${cells[column]}", the claim says '
            '"$expected"',
          );
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('every footnote the table uses is defined under Upstream limits', () {
    final (rows: _, :footnotes) = _supportTable(document);
    final limits = document.substring(document.indexOf('## Upstream limits'));
    final defined = RegExp(
      r'^- \[([a-z])\] ',
      multiLine: true,
    ).allMatches(limits).map((m) => m[1]!).toSet();
    expect(footnotes, isNotEmpty);
    expect(footnotes.difference(defined), isEmpty);
  });
}
