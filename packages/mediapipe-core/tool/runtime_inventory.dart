import 'dart:convert';

import 'package:mediapipe_core/native_assets.dart';

/// Prints Google's libraries the hooks bundle, as JSON for
/// `tool/mirror_runtime_assets.py` and the fresh-app harnesses
/// (`tool/consumer_packages.py`): every per-family library `familyRuntimes`
/// pins, with its URLs in fallback order: the member of Google's archive,
/// then the mirror.
void main() {
  print(
    jsonEncode([
      for (final MapEntry(key: family, value: targets)
          in familyRuntimes.entries)
        for (final MapEntry(key: target, value: runtime) in targets.entries)
          {
            'family': family,
            'target': target,
            'file': runtime.fileName,
            'sha256': runtime.sha256,
            'urls': runtime.asset.urls.toList(),
          },
    ]),
  );
}
