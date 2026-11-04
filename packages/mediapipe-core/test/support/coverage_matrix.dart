// The check behind every family's test/coverage_matrix_test.dart, which
// imports this file by path (tests are not published).
//
// The CI coverage gate (tool/coverage/gate.py) requires a passing row for
// every 'required' and 'device' cell of tool/coverage/matrix.json. This keeps
// that matrix and a family's capability claims from drifting: a required cell
// must be a claimed capability, and an 'unsupported' cell must not be.
// tool/check_repository.py checks that one family claims each task.
import 'dart:convert';
import 'dart:io';

import 'package:mediapipe_core/mediapipe_core.dart';

/// A hardware WebGPU adapter as the browsers' web plugins report it, for
/// families whose browser tasks run only on one.
const hardwareWebGpu = 'WebGPU apple metal-3';

/// The cells of `tool/coverage/matrix.json` for the tasks in [claims] that
/// disagree with what each task claims on the matrix's platforms. Browsers
/// report [webGpu] as their adapter. Run from a package folder.
List<String> coverageMatrixProblems(
  Map<String, TaskCapabilities Function(TaskPlatform)> claims, {
  String? webGpu,
}) {
  final platforms = {
    'web': TaskPlatform(
      operatingSystem: 'web',
      architecture: 'unknown',
      gpu: webGpu,
    ),
    'android': const TaskPlatform(
      operatingSystem: 'android',
      architecture: 'arm64',
    ),
    'ios': const TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '15.0',
    ),
    'macos': const TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '14.0',
    ),
    'linux': const TaskPlatform(operatingSystem: 'linux', architecture: 'x64'),
    'windows': const TaskPlatform(
      operatingSystem: 'windows',
      architecture: 'x64',
    ),
  };
  final matrix =
      jsonDecode(
            File('../../tool/coverage/matrix.json').readAsStringSync(),
          )['cells']
          as Map<String, Object?>;
  final problems = <String>[];
  for (final MapEntry(key: task, value: claim) in claims.entries) {
    final cells = matrix[task] as Map<String, Object?>?;
    if (cells == null) {
      problems.add('$task has no row in tool/coverage/matrix.json');
      continue;
    }
    for (final MapEntry(key: name, value: platform) in platforms.entries) {
      final claimed = claim(platform).supportedDelegates;
      final statuses = cells[name]! as Map<String, Object?>;
      for (final delegate in Delegate.values) {
        final status = statuses[delegate.name]! as String;
        final cell = '$task / $name / ${delegate.name}';
        if ((status == 'required' || status == 'device') &&
            !claimed.contains(delegate)) {
          problems.add('$cell is $status but not claimed');
        }
        if (status.startsWith('unsupported') && claimed.contains(delegate)) {
          problems.add('$cell is claimed but marked "$status"');
        }
      }
    }
  }
  return problems;
}
