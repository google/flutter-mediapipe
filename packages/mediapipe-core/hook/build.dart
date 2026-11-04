import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';

/// Forwards the app's download setting to the family hooks.
///
/// Each family bundles Google's MediaPipe library for that family
/// (`bundleFamilyRuntime`), so an app ships only the families it depends on.
/// `hooks.user_defines.mediapipe_core.asset_source` reaches only this hook,
/// so it passes the setting on as metadata (`hookAssetSource`).
Future<void> main(List<String> arguments) =>
    build(arguments, (input, output) async {
      final source = hookAssetSource(input);
      if (source != null) output.metadata['asset_source'] = source;
    });
