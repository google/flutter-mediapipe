/// Google's native runtime where the compiler has `dart:io`, and a stub that
/// names the missing browser plugin elsewhere. The two export the same names.
library;

export 'native_stub.dart'
    if (dart.library.io) 'io/native_audio_classifier.dart';
