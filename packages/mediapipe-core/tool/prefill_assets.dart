import 'dart:convert';
import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';

/// Consumes the reviewed source inventory from `tool/mirror_runtime_assets.py`.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/prefill_assets.dart <directory>');
    exit(64);
  }
  final entries =
      jsonDecode(await stdin.transform(utf8.decoder).join()) as List;
  final directory = Directory(args.single);
  await directory.create(recursive: true);
  for (final entry in entries.cast<Map<String, dynamic>>()) {
    final urls = (entry['urls'] as List).cast<String>();
    final digest = entry['sha256'] as String;
    final asset = DownloadAsset(
      url: urls.first,
      mirrors: urls.skip(1).toList(),
      sha256: digest,
    );
    await downloadVerified(
      asset,
      File.fromUri(directory.uri.resolve(digest)),
      source: '',
    );
    stdout.writeln('$digest ${entry['release_asset']}');
  }
}
