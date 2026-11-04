/// Releases a browser frame the package accepted but will not run. Browser
/// frames exist in browsers only, so elsewhere there is nothing to release.
library;

export 'browser_frames_stub.dart'
    if (dart.library.js_interop) 'browser_frames_web.dart';
