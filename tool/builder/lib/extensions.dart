import 'dart:convert';
import 'dart:io';

extension EasyOutput on Process {
  Future<List<String>> get processedStdErr => _process(this.stderr);

  Future<List<String>> get processedStdOut => _process(this.stdout);

  Future<List<String>> _process(Stream<List<int>> stream) async {
    return utf8.decoder
        .convert((await stream.toList())
            .fold<List<int>>([], (arr, el) => arr..addAll(el)))
        .split('\n');
  }
}

/// Returns the last full chunk from a Url-like String.
///
/// From "/an/awesome/url/", returns "url".
/// From "/an/awesome/url", returns "url".
/// From "/an/awesome/url/", with a depth of 1, returns "awesome"
/// From "/an/awesome/url", with a depth of 1, returns "awesome"
String lastChunk(String url, {int depth = 0, String delimiter = '/'}) {
  final indexOffset = (url.endsWith(delimiter)) ? -2 - depth : -1 - depth;
  final splitUrl = url.split(delimiter);
  return splitUrl[splitUrl.length + indexOffset];
}

extension DefaultableMap<K, V> on Map {
  void setDefault(K key, V def) {
    if (!containsKey(key)) {
      this[key] = def;
    }
  }
}
