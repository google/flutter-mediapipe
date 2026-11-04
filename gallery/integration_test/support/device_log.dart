import 'dart:convert';

/// Keeps [record] in the device log (logcat, the simulator console) under
/// [tag], for the record; any timing in it is diagnostic, not a benchmark.
void logRecord(String tag, Map<String, Object?> record) {
  // ignore: avoid_print
  print('$tag ${jsonEncode(record)}');
}
