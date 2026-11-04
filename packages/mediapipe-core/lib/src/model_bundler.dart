import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'download_asset.dart';
import 'model_bundle.dart';
import 'verified_download.dart';

// The implementation of `dart run mediapipe_core:bundle_models`, kept free of
// Flutter so the command and its tests run as plain Dart.

/// Task families whose models an app can bundle, with the class whose
/// `byName` map lists them.
const bundlableFamilies = {
  'mediapipe_vision': 'VisionModels',
  'mediapipe_text': 'TextModels',
  'mediapipe_audio': 'AudioModels',
  'mediapipe_decision': 'DecisionModels',
  'mediapipe_retrieval': 'RetrievalModels',
};

final _sha256Name = RegExp(r'^[a-f0-9]{64}$');

/// The model names an app lists under `hooks.user_defines.<family>.models`,
/// by family, without duplicates.
Map<String, List<String>> listedModels(Object? pubspec) {
  final listed = <String, List<String>>{};
  for (final family in bundlableFamilies.keys) {
    final value = _at(pubspec, ['hooks', 'user_defines', family, 'models']);
    if (value == null) continue;
    if (value is! List || value.any((name) => name is! String || name == '')) {
      throw FormatException(
        'hooks.user_defines.$family.models must be a list of model names, '
        'such as [face_landmarker].',
      );
    }
    listed[family] = value.cast<String>().toSet().toList();
  }
  return listed;
}

/// `hooks.user_defines.mediapipe_core.asset_source`: a mirror URL, or a
/// directory resolved against [appRoot], as the build hooks read it.
String? bundleSource(Object? pubspec, Directory appRoot) {
  final value = _at(pubspec, [
    'hooks',
    'user_defines',
    'mediapipe_core',
    'asset_source',
  ]);
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const FormatException(
      'hooks.user_defines.mediapipe_core.asset_source must be a directory or '
      'an http(s) URL.',
    );
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return Directory.fromUri(appRoot.uri.resolve(value)).absolute.path;
}

/// Whether the app declares [bundledModelsFolder] under `flutter: assets:`.
bool declaresBundledModels(Object? pubspec) {
  final assets = _at(pubspec, ['flutter', 'assets']);
  if (assets is! List) return false;
  for (final asset in assets) {
    final path = asset is Map ? asset['path'] : asset;
    if (path is! String) continue;
    final normalized = path.startsWith('./') ? path.substring(2) : path;
    if (normalized == bundledModelsFolder ||
        '$normalized/' == bundledModelsFolder) {
      return true;
    }
  }
  return false;
}

Object? _at(Object? node, List<String> path) {
  for (final key in path) {
    if (node is! Map) return null;
    node = node[key];
  }
  return node;
}

/// One family's listed names and its pinned models by name.
final class FamilyModels {
  /// The names [family] lists, resolved against its [registry].
  const FamilyModels(this.family, this.names, this.registry);

  /// The package, such as `mediapipe_vision`.
  final String family;

  /// The names listed in pubspec.yaml.
  final List<String> names;

  /// The family's `XxxModels.byName`.
  final Map<String, DownloadAsset> registry;
}

/// What [bundleModels] did, and why it failed if it did.
final class BundleResult {
  /// Wraps the console [lines] and any [problems].
  const BundleResult(this.lines, this.problems);

  /// What happened, one line each.
  final List<String> lines;

  /// Why the command fails; empty on success.
  final List<String> problems;

  /// Whether the app's bundled models match its pubspec.
  bool get ok => problems.isEmpty;
}

/// Brings `assets/mediapipe/` under [appRoot] in line with [families]: each
/// listed model downloaded (from [source] when set), verified against its
/// pinned SHA-256 and named by it, unlisted ones removed, and a manifest
/// written. With [check], nothing is downloaded or written; it only reports
/// what is out of date. [declared] says whether pubspec.yaml lists the folder
/// under `flutter: assets:`.
Future<BundleResult> bundleModels(
  Directory appRoot,
  List<FamilyModels> families, {
  required bool declared,
  String? source,
  bool check = false,
}) async {
  final lines = <String>[];
  final problems = <String>[];
  final wanted = <String, (String, DownloadAsset)>{};
  for (final family in families) {
    for (final name in family.names) {
      final model = family.registry[name];
      if (model == null) {
        problems.add(
          'hooks.user_defines.${family.family}.models lists "$name", which is '
          'not one of its models: ${family.registry.keys.join(', ')}.',
        );
        continue;
      }
      wanted.putIfAbsent(
        model.sha256,
        () => ('${family.family}: $name', model),
      );
    }
  }
  if (problems.isNotEmpty) return BundleResult(lines, problems);

  final folder = Directory.fromUri(appRoot.uri.resolve(bundledModelsFolder));
  final present = <String>{};
  if (await folder.exists()) {
    await for (final entry in folder.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && _sha256Name.hasMatch(name)) present.add(name);
    }
  }
  if (wanted.isEmpty && !declared && !await folder.exists()) {
    return BundleResult([
      'No models are listed. Add them under '
          'hooks.user_defines.<family>.models in pubspec.yaml.',
    ], problems);
  }
  if (!check) await folder.create(recursive: true);

  var total = 0;
  for (final MapEntry(key: digest, value: (label, model)) in wanted.entries) {
    final file = File.fromUri(folder.uri.resolve(digest));
    final current = present.contains(digest) && await _digest(file) == digest;
    if (check) {
      if (!current) {
        problems.add(
          '$label is missing from $bundledModelsFolder or does not match its '
          'pin. Run `dart run mediapipe_core:bundle_models`.',
        );
        continue;
      }
    } else if (!current) {
      try {
        await downloadVerified(model, file, source: source);
      } on DownloadException catch (error) {
        problems.add('Could not download $label. $error');
        continue;
      }
    }
    final size = await file.length();
    total += size;
    lines.add('${current ? 'Up to date' : 'Downloaded'}: $label, ${_mb(size)}');
  }

  for (final digest in present.difference(wanted.keys.toSet())) {
    if (check) {
      problems.add(
        '$bundledModelsFolder$digest is no longer listed in pubspec.yaml. '
        'Run `dart run mediapipe_core:bundle_models` to remove it.',
      );
    } else {
      await File.fromUri(folder.uri.resolve(digest)).delete();
      lines.add('Removed $bundledModelsFolder$digest, no longer listed');
    }
  }

  final manifest = File.fromUri(folder.uri.resolve(bundledModelsManifest));
  final expected = _manifest(wanted);
  if (check) {
    if (!await manifest.exists() || await manifest.readAsString() != expected) {
      problems.add(
        '$bundledModelsFolder$bundledModelsManifest is out of date. Run '
        '`dart run mediapipe_core:bundle_models`.',
      );
    }
  } else {
    await manifest.writeAsString(expected);
  }

  if (!declared && wanted.isNotEmpty) {
    problems.add(
      'pubspec.yaml does not declare $bundledModelsFolder under flutter: '
      'assets:, so builds would leave the models out. Add:\n\n'
      'flutter:\n  assets:\n    - $bundledModelsFolder',
    );
  }
  if (problems.isEmpty) {
    lines.add(
      check
          ? '$bundledModelsFolder matches pubspec.yaml: ${wanted.length} '
                'model${wanted.length == 1 ? '' : 's'}, ${_mb(total)}.'
          : 'Bundled ${wanted.length} model${wanted.length == 1 ? '' : 's'} '
                '(${_mb(total)}) in $bundledModelsFolder.',
    );
  }
  return BundleResult(lines, problems);
}

/// The source of the program that reads [families]' `byName` maps. It runs
/// with the app's package configuration, which can import the families that
/// mediapipe_core itself cannot depend on.
String registryProgram(List<String> families) {
  final buffer = StringBuffer()
    ..writeln(
      '// Generated by `dart run mediapipe_core:bundle_models`; safe to delete.',
    )
    ..writeln("import 'dart:isolate';")
    ..writeln()
    ..writeln("import 'package:mediapipe_core/mediapipe_core.dart';");
  for (final (index, family) in families.indexed) {
    buffer.writeln("import 'package:$family/models.dart' as family$index;");
  }
  buffer
    ..writeln()
    ..writeln('void main(List<String> arguments, SendPort reply) {')
    ..writeln('  reply.send({');
  for (final (index, family) in families.indexed) {
    buffer.writeln(
      "    '$family': _plain(family$index.${bundlableFamilies[family]}.byName),",
    );
  }
  buffer
    ..writeln('  });')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'Map<String, List<Object>> _plain(Map<String, DownloadAsset> models) =>',
    )
    ..writeln('    {')
    ..writeln('      for (final MapEntry(:key, :value) in models.entries)')
    ..writeln('        key: [value.url, value.sha256, value.mirrors],')
    ..writeln('    };');
  return buffer.toString();
}

/// Rebuilds a family's models from what [registryProgram] sends back.
Map<String, DownloadAsset> decodeRegistry(Map<Object?, Object?> message) => {
  for (final MapEntry(:key, :value) in message.entries)
    if (value case [final String url, final String sha256, final List mirrors])
      key! as String: DownloadAsset(
        url: url,
        sha256: sha256,
        mirrors: mirrors.cast<String>(),
      ),
};

String _manifest(Map<String, (String, DownloadAsset)> wanted) {
  final models = [
    for (final MapEntry(key: digest, value: (label, model)) in wanted.entries)
      {'model': label, 'file': digest, 'url': model.url},
  ]..sort((a, b) => a['model']!.compareTo(b['model']!));
  return '${const JsonEncoder.withIndent('  ').convert({'note': 'Written by `dart run mediapipe_core:bundle_models`. List models in pubspec.yaml instead of editing this file.', 'models': models})}\n';
}

Future<String> _digest(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
