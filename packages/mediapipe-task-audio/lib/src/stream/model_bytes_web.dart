import 'dart:js_interop';
import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:web/web.dart' as web;

/// Downloads the model at [path], resolved against the page as the browser
/// workers resolve it. The stream then hands the bytes to its worker in place
/// of the URL, so the model is downloaded once.
Future<Uint8List> readModelBytes(String path) async {
  final url = Uri.base.resolve(path).toString();
  final web.Response response;
  try {
    response = await web.window.fetch(url.toJS).toDart;
  } catch (error) {
    throw TaskException(
      'Could not download the model $url: $error',
      cause: error,
    );
  }
  if (!response.ok) {
    throw TaskException(
      'Could not download the model $url: HTTP ${response.status}.',
    );
  }
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}
