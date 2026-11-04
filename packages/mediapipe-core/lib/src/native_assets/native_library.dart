import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

export '../download_asset.dart';
export '../verified_download.dart' show downloadVerified;

/// Where build hooks fetch pinned assets instead of their URLs, for offline
/// and mirrored builds: `hooks.user_defines.mediapipe_core.asset_source`,
/// a directory (relative to the app's pubspec) or an http(s) root holding
/// files named by their SHA-256.
///
/// It is a build setting, not the `MEDIAPIPE_ASSET_SOURCE` environment
/// variable that command-line tools read, because the hook runner passes
/// hooks only an allowlist of variables. Core's hook reads it and forwards it
/// to the family hooks as metadata.
String? hookAssetSource(BuildInput input) {
  if (input.packageName != 'mediapipe_core') {
    return input.metadata['mediapipe_core']['asset_source'] as String?;
  }
  final value = input.userDefines['asset_source'];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const FormatException(
      'mediapipe_core.asset_source must be a directory or an http(s) '
      'URL.',
    );
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return input.userDefines.path('asset_source')!.toFilePath();
}

/// The build target a hook produces assets for: `macos/arm64`,
/// `ios-simulator/arm64`, `ios/arm64`, `linux/x64`, `windows/arm64`, and so on.
///
/// Runtime tables are keyed by this string. The iOS simulator is a separate
/// target because its binaries are built with a different SDK than devices.
String buildTarget(CodeConfig code) {
  final os = code.targetOS;
  final platform = os == OS.iOS && code.iOS.targetSdk == IOSSdk.iPhoneSimulator
      ? 'ios-simulator'
      : os.toString();
  return '$platform/${code.targetArchitecture}';
}

/// Rejects static linking, which no MediaPipe runtime supports.
void requireDynamicLinking(CodeConfig code) {
  if (code.linkModePreference == LinkModePreference.static) {
    throw UnsupportedError('MediaPipe requires dynamic library bundling.');
  }
}
