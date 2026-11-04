/// Where browsers load Google's MediaPipe runtime from, one setting for every
/// task family.
library;

/// The browser runtime's location, shared by the vision, text and audio
/// packages. Exists on every platform; only browsers read it.
abstract final class MediaPipeWebRuntime {
  // TODO: Load each family's runtime from a copy its package ships, with
  // jsDelivr and unpkg only as fallbacks, so one CDN's outage stops no app.
  // See packages/mediapipe-core/tool/ASSET_HOSTING.md.
  /// jsDelivr's copy of npm, where each family's pinned runtime loads from
  /// unless the app sets [baseUrl].
  static const defaultBaseUrl = 'https://cdn.jsdelivr.net/npm/';

  /// An npm-style root: each family loads Google's pinned runtime from
  /// `<baseUrl>@mediapipe/tasks-<family>@<version>/`.
  ///
  /// Point it at another npm CDN (such as `https://unpkg.com/`), an internal
  /// mirror, or a folder the app serves. `dart run
  /// mediapipe_core:web_runtime web/mediapipe` fills that folder with
  /// the verified runtimes of the families the app uses; `mediapipe/` then
  /// names it, since relative URLs resolve against the page. Set it before
  /// creating the first task. Native platforms ignore it.
  static String baseUrl = defaultBaseUrl;

  /// [baseUrl] as an absolute directory URL, resolved against [page].
  static String resolve(Uri page) =>
      page.resolve(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/').toString();
}
