import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Closes an `ImageBitmap` or `VideoFrame`, which holds its pixels, often in
/// GPU memory, until it is closed.
void releaseBrowserFrame(Object frame) {
  final object = frame as JSObject;
  if (object.has('close')) object.callMethod<JSAny?>('close'.toJS);
}
