/// Checks every package's public libraries: each family's app-facing API is
/// identical on native and web, within the conventions and free of
/// collisions with Dart's and Flutter's names, and every public library
/// equals its reviewed snapshot. `--update` rewrites the baseline and
/// snapshots.
library;

import 'dart:io';

import 'package:api_parity/api_dump.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Libraries an app imports beside a family; a public name they also export
/// could not be used from such an app without a prefix.
const collisionLibraries = [
  'dart:core',
  'dart:async',
  'dart:collection',
  'dart:typed_data',
  'dart:math',
  'package:flutter/foundation.dart',
  'package:flutter/services.dart',
  'package:flutter/widgets.dart',
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
];

/// The first line of a family's app-facing snapshot: everything core's
/// app-facing library declares, which every family re-exports unchanged.
const includeCore = 'include package:mediapipe_core/mediapipe_core.dart';

/// One package under `packages/`: `mediapipe_<family>` in [directory].
typedef Package = ({String family, String name, String directory});

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('update', help: 'Rewrite the baseline and the snapshots.')
    ..addOption('root', help: 'Repository root; defaults to this checkout.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout.writeln('dart run bin/api_parity.dart [--update] [--root DIR]\n');
    stdout.writeln(parser.usage);
    return;
  }
  final root = p.normalize(
    p.absolute(
      args.option('root') ??
          p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
    ),
  );
  final tool = p.join(root, 'tool', 'api_parity');
  final packages = _packages(root);
  final findings = <String>[];
  final snapshots = <String, String>{};
  // Core's app-facing API, by snapshot suffix ('' or '.web').
  final coreApi = <String, List<String>>{};

  final reserved = await _reservedNames(packages.last.directory);
  for (final package in packages) {
    final family = package.family;
    for (final file in _libraries(package.directory)) {
      final uri = 'package:${package.name}/$file';
      final appFacing = file == '${package.name}.dart';
      stdout.writeln('Analyzing $uri');
      final native = await dumpLibrary(
        packageRoot: package.directory,
        uri: uri,
        declaredVariables: nativeLibraries,
      );
      final web = await dumpLibrary(
        packageRoot: package.directory,
        uri: uri,
        declaredVariables: webLibraries,
      );
      final nativeLines = native.lines.toSet();
      final webLines = web.lines.toSet();
      final dumps = {
        '': native.lines,
        // Only while the web API still differs.
        if (!nativeLines.containsAll(webLines) ||
            !webLines.containsAll(nativeLines))
          '.web': web.lines,
      };
      if (appFacing) _check(family, native, web, reserved, findings);
      for (final MapEntry(key: suffix, value: lines) in dumps.entries) {
        if (appFacing && family == 'core') coreApi[suffix] = lines;
        final snapshot = appFacing && family != 'core'
            ? _withoutCore(
                family,
                lines,
                coreApi[suffix] ?? coreApi['']!,
                findings,
              )
            : lines;
        final name = p.join(family, p.basenameWithoutExtension(file));
        snapshots['$name$suffix.txt'] = '${snapshot.join('\n')}\n';
      }
    }
  }

  final baselineFile = File(p.join(tool, 'baseline.txt'));
  final snapshotDirectory = Directory(p.join(tool, 'snapshots'));
  final recorded = {
    if (snapshotDirectory.existsSync())
      for (final file in snapshotDirectory.listSync(recursive: true))
        if (file is File) p.relative(file.path, from: snapshotDirectory.path),
  };
  final stale = recorded.difference(snapshots.keys.toSet());
  if (args.flag('update')) {
    baselineFile.writeAsStringSync(_baseline(findings));
    for (final name in stale) {
      File(p.join(snapshotDirectory.path, name)).deleteSync();
    }
    for (final MapEntry(key: name, value: content) in snapshots.entries) {
      File(p.join(snapshotDirectory.path, name))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }
    stdout.writeln(
      'Wrote ${findings.length} baseline entries and '
      '${snapshots.length} snapshots.',
    );
    return;
  }

  final baseline = baselineFile.existsSync()
      ? baselineFile
            .readAsLinesSync()
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toSet()
      : <String>{};
  final failures = <String>[];
  for (final finding in findings) {
    if (!baseline.contains(finding)) failures.add('new: $finding');
  }
  for (final entry in baseline) {
    if (!findings.contains(entry)) failures.add('fixed, prune: $entry');
  }
  for (final MapEntry(key: name, value: content) in snapshots.entries) {
    final file = File(p.join(snapshotDirectory.path, name));
    if (!file.existsSync()) {
      failures.add('snapshot missing: $name');
    } else if (file.readAsStringSync() != content) {
      failures.add('snapshot differs: $name');
    }
  }
  for (final name in stale) {
    failures.add('snapshot of no library: $name');
  }
  if (failures.isEmpty) {
    stdout.writeln(
      'API parity: ${findings.length} known findings, '
      '${snapshots.length} snapshots unchanged.',
    );
    return;
  }
  stderr.writeln('API parity check failed:');
  for (final failure in failures) {
    stderr.writeln('  $failure');
  }
  stderr.writeln(
    'Review the change, then run `dart run tool/api_parity/bin/api_parity.dart '
    '--update` and commit baseline.txt and snapshots/.',
  );
  exitCode = 1;
}

/// Every package under `packages/`, core first: each folder with a pubspec.
List<Package> _packages(String root) {
  final packages = <Package>[];
  for (final entry in Directory(p.join(root, 'packages')).listSync()) {
    final pubspec = File(p.join(entry.path, 'pubspec.yaml'));
    if (entry is! Directory || !pubspec.existsSync()) continue;
    final name = RegExp(
      r'^name: (\S+)$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())!.group(1)!;
    packages.add((
      family: name.substring('mediapipe_'.length),
      name: name,
      directory: entry.path,
    ));
  }
  int rank(Package package) => package.family == 'core' ? 0 : 1;
  return packages..sort(
    (a, b) =>
        rank(a) != rank(b) ? rank(a) - rank(b) : a.family.compareTo(b.family),
  );
}

/// The public libraries of the package in [directory]: `lib/*.dart`.
List<String> _libraries(String directory) => [
  for (final entry in Directory(p.join(directory, 'lib')).listSync())
    if (entry is File && entry.path.endsWith('.dart')) p.basename(entry.path),
]..sort();

/// Records the parity, platform-type, convention and collision findings of
/// [family]'s app-facing library.
void _check(
  String family,
  ApiDump native,
  ApiDump web,
  Map<String, String> reserved,
  List<String> findings,
) {
  final nativeLines = native.lines.toSet();
  final webLines = web.lines.toSet();
  for (final line in native.lines) {
    if (!webLines.contains(line)) {
      findings.add('[$family] native only: ${line.trim()}');
    }
  }
  for (final line in web.lines) {
    if (!nativeLines.contains(line)) {
      findings.add('[$family] web only: ${line.trim()}');
    }
  }
  for (final finding in {...native.platformTypes, ...web.platformTypes}) {
    findings.add('[$family] platform type: $finding');
  }
  for (final finding in {...native.conventions, ...web.conventions}) {
    findings.add('[$family] convention: $finding');
  }
  for (final name in {...native.names, ...web.names}.toList()..sort()) {
    if (reserved[name] case final library?) {
      findings.add('[$family] collision: $name is also in $library');
    }
  }
}

/// [lines], a family's app-facing API, as [includeCore] and the declarations
/// that are not [core]'s. A core declaration the family does not re-export
/// unchanged is a finding.
List<String> _withoutCore(
  String family,
  List<String> lines,
  List<String> core,
  List<String> findings,
) {
  final blocks = _declarations(lines);
  final shared = _declarations(core);
  for (final declaration in shared) {
    if (!blocks.contains(declaration)) {
      findings.add(
        '[$family] does not re-export core: ${declaration.split('\n').first}',
      );
    }
  }
  final coreSet = shared.toSet();
  return [
    includeCore,
    for (final block in blocks)
      if (!coreSet.contains(block)) block,
  ];
}

/// [lines] as declarations: each top-level line with its indented members.
List<String> _declarations(List<String> lines) {
  final blocks = <List<String>>[];
  for (final line in lines) {
    if (line.startsWith(' ') && blocks.isNotEmpty) {
      blocks.last.add(line);
    } else {
      blocks.add([line]);
    }
  }
  return [for (final block in blocks) block.join('\n')];
}

String _baseline(List<String> findings) {
  final buffer = StringBuffer()
    ..writeln(
      '# Findings the public API still has: differences between the native and '
      'web\n# APIs, platform types in signatures, convention gaps and name '
      'collisions.\n# `dart run tool/api_parity/bin/api_parity.dart --update` '
      'rewrites it; it may only shrink.',
    );
  for (final finding in findings) {
    buffer.writeln(finding);
  }
  return buffer.toString();
}

/// Every public name the [collisionLibraries] export, with the first library
/// that exports it. Resolved from [packageRoot], a family, which depends on
/// Flutter.
Future<Map<String, String>> _reservedNames(String packageRoot) async {
  final reserved = <String, String>{};
  for (final uri in collisionLibraries) {
    final library = await resolveLibrary(
      packageRoot: packageRoot,
      uri: uri,
      declaredVariables: nativeLibraries,
    );
    for (final name in library.exportNamespace.definedNames2.keys) {
      reserved.putIfAbsent(name, () => uri);
    }
  }
  return reserved;
}
