// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.0.1 Python ctypes: core/base_options_c.py,
// components/processors/classifier_options_c.py,
// components/containers/classification_result_c.py and
// components/containers/embedding_result_c.py.

/// Google's MediaPipe C structs that more than one family binds, from the
/// release core pins for every family (`family_runtimes.dart`), and the
/// helpers that fill and copy them. For the family packages' FFI bindings,
/// whose ABI tests check every size and field offset against Google's wheel;
/// not for applications.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/classifier_settings.dart';
import 'src/exceptions.dart';
import 'src/host_io.dart';
import 'src/value_types.dart';

/// `MpBaseOptions`: the model, delegate and host every task's options embed.
final class MpBaseOptions extends Struct {
  /// The model's contents, or null to read [modelAssetPath].
  external Pointer<Char> modelAssetBuffer;

  /// The length of [modelAssetBuffer] in bytes, or 0.
  @Uint32()
  external int modelAssetBufferCount;

  /// The model file Google opens and maps into memory.
  external Pointer<Char> modelAssetPath;

  /// A model file opened with `open(2)`, or -1 for none.
  @Int32()
  external int fileDescriptor;

  /// The `MpDelegate` the graph runs on: 0 is the CPU, 1 the GPU.
  @Int32()
  external int delegate;

  /// The `MpHostEnvironment` Google's usage log records: 5 is
  /// Flutter.
  @Int32()
  external int hostEnvironment;

  /// The `MpHostSystem`: the OS the task runs on.
  @Int32()
  external int hostSystem;

  /// The host's version, which Google's usage log records.
  external Pointer<Char> hostVersion;

  /// The CA bundle Google's usage logging uses, or null.
  external Pointer<Char> caBundlePath;

  /// The app's ID, such as an Android package name, or null.
  external Pointer<Char> appId;

  /// The app's version, such as an Android version code, or null.
  external Pointer<Char> appVersion;
}

/// `MpClassifierOptions`: the classifiers' result filtering.
final class MpClassifierOptions extends Struct {
  /// The locale of the model metadata's display names, or null
  /// for English.
  external Pointer<Char> displayNamesLocale;

  /// The most categories to return: negative for all; 0 is an error.
  @Int32()
  external int maxResults;

  /// The score below which categories are dropped, replacing the
  /// model metadata's.
  @Float()
  external double scoreThreshold;

  /// The only category names to keep, or null for all.
  external Pointer<Pointer<Char>> categoryAllowlist;

  /// The number of names in [categoryAllowlist].
  @Uint32()
  external int categoryAllowlistCount;

  /// Category names to drop, or null for none.
  external Pointer<Pointer<Char>> categoryDenylist;

  /// The number of names in [categoryDenylist].
  @Uint32()
  external int categoryDenylistCount;
}

/// `MpCategory`: one class and its score.
final class MpCategory extends Struct {
  /// The category's index in the model's output.
  @Int32()
  external int index;

  /// The category's score, often a probability.
  @Float()
  external double score;

  /// The label map's ID for the category, or null.
  external Pointer<Char> categoryName;

  /// The label map's human-readable name for the category, or
  /// null.
  external Pointer<Char> displayName;
}

/// `MpClassifications`: one classifier head's categories.
final class MpClassifications extends Struct {
  /// The categories, usually by descending score.
  external Pointer<MpCategory> categories;

  /// The number of entries in [categories].
  @Uint32()
  external int categoriesCount;

  /// The index of the classifier head (output tensor).
  @Int32()
  external int headIndex;

  /// The head's name from the model metadata, or null.
  external Pointer<Char> headName;
}

/// `MpClassificationResult`: every head, with a timestamp.
final class MpClassificationResult extends Struct {
  /// One entry per head of the model.
  external Pointer<MpClassifications> classifications;

  /// The number of entries in [classifications].
  @Uint32()
  external int classificationsCount;

  /// The start of the input chunk these results cover, in
  /// milliseconds, when [hasTimestampMs].
  @Int64()
  external int timestampMs;

  /// Whether [timestampMs] holds a value.
  @Bool()
  external bool hasTimestampMs;
}

/// `MpEmbedding`: one head's vector, as floats or quantized bytes.
final class MpEmbedding extends Struct {
  /// The float vector, or null when the embedder quantizes.
  external Pointer<Float> floatEmbedding;

  /// The scalar-quantized vector, or null when it does not.
  external Pointer<Uint8> quantizedEmbedding;

  /// The number of values in the vector.
  @Uint32()
  external int valuesCount;

  /// The index of the embedder head (output tensor).
  @Int32()
  external int headIndex;

  /// The head's name from the model metadata, or null.
  external Pointer<Char> headName;
}

/// `MpEmbeddingResult`: every head, with a timestamp.
final class MpEmbeddingResult extends Struct {
  /// One entry per head of the model.
  external Pointer<MpEmbedding> embeddings;

  /// The number of entries in [embeddings].
  @Uint32()
  external int embeddingsCount;
  // The C header's order and size (32 bytes). Google's Python ctypes put the
  // flag first and declare 24 bytes, which the library overruns.
  /// The start of the input chunk these results cover, in
  /// milliseconds, when [hasTimestampMs].
  @Int64()
  external int timestampMs;

  /// Whether [timestampMs] holds a value.
  @Bool()
  external bool hasTimestampMs;
}

/// Fills Google's base options for the CPU, the only delegate the C API
/// families run on, with the model at [modelPath] or in [modelBytes], and the
/// host as Flutter on this OS, with [mpHostVersion], which Google's usage log
/// records (it records neither while the environment is unknown). Bytes and
/// strings are copied into [arena], which may free them once the task exists:
/// Google copies them when it creates the task.
void fillBaseOptions(
  MpBaseOptions target,
  Arena arena, {
  String? modelPath,
  Uint8List? modelBytes,
}) {
  target
    ..fileDescriptor = -1
    ..delegate = 0
    // MP_HOST_ENVIRONMENT_FLUTTER.
    ..hostEnvironment = 5
    ..hostSystem = mpHostSystem
    ..hostVersion = mpHostVersion.toNativeUtf8(allocator: arena).cast();
  if (modelBytes != null) {
    final buffer = arena<Uint8>(modelBytes.length);
    buffer.asTypedList(modelBytes.length).setAll(0, modelBytes);
    target
      ..modelAssetBuffer = buffer.cast()
      ..modelAssetBufferCount = modelBytes.length;
  } else {
    target.modelAssetPath = nativeModelPath(
      modelPath!,
    ).toNativeUtf8(allocator: arena).cast();
  }
}

/// Fills Google's classifier options from [settings], every string in
/// [arena].
void fillClassifierOptions(
  MpClassifierOptions target,
  Arena arena,
  ClassifierSettings settings,
) {
  target
    ..displayNamesLocale =
        settings.displayNamesLocale?.toNativeUtf8(allocator: arena).cast() ??
        nullptr
    ..maxResults = settings.maxResults
    ..scoreThreshold = settings.scoreThreshold
    ..categoryAllowlist = nativeStrings(arena, settings.categoryAllowlist)
    ..categoryAllowlistCount = settings.categoryAllowlist.length
    ..categoryDenylist = nativeStrings(arena, settings.categoryDenylist)
    ..categoryDenylistCount = settings.categoryDenylist.length;
}

/// Copies [values] into a C string array in [arena], or null when there are
/// none.
Pointer<Pointer<Char>> nativeStrings(Arena arena, List<String> values) {
  if (values.isEmpty) return nullptr;
  final array = arena<Pointer<Char>>(values.length);
  for (var i = 0; i < values.length; i++) {
    array[i] = values[i].toNativeUtf8(allocator: arena).cast();
  }
  return array;
}

/// Copies every head of Google's [result] before Google frees it.
List<Classifications> copyClassifications(MpClassificationResult result) => [
  for (var i = 0; i < result.classificationsCount; i++)
    _copyHead(result.classifications[i]),
];

Classifications _copyHead(MpClassifications head) => Classifications(
  categories: [
    for (var i = 0; i < head.categoriesCount; i++)
      MediaPipeCategory(
        index: head.categories[i].index,
        score: head.categories[i].score,
        categoryName: nativeString(head.categories[i].categoryName),
        displayName: nativeString(head.categories[i].displayName),
      ),
  ],
  headIndex: head.headIndex,
  headName: nativeString(head.headName),
);

/// Copies Google's C string, or null for a null pointer. With [emptyIsNull],
/// an empty string is null too, as Google's Python reads optional strings.
String? nativeString(Pointer<Char> value, {bool emptyIsNull = false}) {
  if (value == nullptr) return null;
  final text = value.cast<Utf8>().toDartString();
  return emptyIsNull && text.isEmpty ? null : text;
}

/// Runs [call], one of Google's C functions that report a failure through an
/// error out-parameter, and throws a failure as a [TaskException] with
/// Google's message and status, or as what [failure] makes of them.
/// [errorFree] is the calling family's `MpErrorFree`, since each family loads
/// its own library; it frees Google's message on every path.
void checkNativeStatus(
  int Function(Pointer<Pointer<Char>> error) call,
  void Function(Pointer<Char> message) errorFree, {
  Object Function(String message, int status)? failure,
}) => using((arena) {
  final error = arena<Pointer<Char>>();
  try {
    final status = call(error);
    if (status != 0) {
      final message =
          nativeString(error.value) ?? 'MediaPipe failed with status $status.';
      throw failure?.call(message, status) ??
          TaskException(message, statusCode: status);
    }
  } finally {
    if (error.value != nullptr) errorFree(error.value);
  }
});
