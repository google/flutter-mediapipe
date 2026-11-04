import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../live/overlay_visibility.dart';
import 'test_hooks.dart';

/// With [testHooks], `window.__hideOverlay(true)` hides the live overlay so
/// the browser suite can photograph the bare preview, and `false` shows it
/// again.
void installOverlayToggle() {
  if (!testHooks || _installed) return;
  _installed = true;
  globalContext['__hideOverlay'] = ((JSBoolean hide) {
    debugHideOverlay = hide.toDart;
  }).toJS;
}

var _installed = false;
