import 'dart:ffi';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:ffi/ffi.dart';
import 'mediapipe_common_bindings.dart' as bindings;
import 'ffi_utils.dart';

class BaseOptions extends Equatable {
  const BaseOptions({this.modelAssetBuffer, this.modelAssetPath})
      : assert(
          !(modelAssetBuffer == null && modelAssetPath == null),
          'You must supply either `modelAssetBuffer` or `modelAssetPath`',
        ),
        assert(
          !(modelAssetBuffer != null && modelAssetPath != null),
          'You must only supply one of `modelAssetBuffer` and `modelAssetPath`',
        );

  /// The model asset file contents as bytes;
  final Uint8List? modelAssetBuffer;

  /// Path to the model asset file.
  final String? modelAssetPath;

  Pointer<bindings.BaseOptions> toStruct() {
    final struct = calloc<bindings.BaseOptions>();

    if (modelAssetPath != null) {
      struct.ref.model_asset_path = prepareString(modelAssetPath!);
    }
    if (modelAssetBuffer != null) {
      struct.ref.model_asset_buffer = prepareUint8List(modelAssetBuffer!);
    }
    return struct;
  }

  @override
  List<Object?> get props => [modelAssetBuffer, modelAssetPath];
}

class ClassifierOptions extends Equatable {
  const ClassifierOptions({
    this.displayNamesLocale,
    this.maxResults,
    this.scoreThreshold,
    this.categoryAllowlist,
    this.categoryDenylist,
  });

  /// The locale to use for display names specified through the TFLite Model
  /// Metadata.
  final String? displayNamesLocale;

  /// The maximum number of top-scored classification results to return.
  final int? maxResults;

  /// Overrides the ones provided in the model metadata.
  ///
  /// Results below this value are rejected.
  final double? scoreThreshold;

  /// Allowlist of category names.
  ///
  /// If non-empty, classification results whose category name is not in
  /// this set will be discarded. Duplicate or unknown category names
  /// are ignored. Mutually exclusive with `categoryDenylist`.
  final List<String>? categoryAllowlist;

  /// Denylist of category names.
  ///
  /// If non-empty, classification results whose category name is in this set
  /// will be discarded. Duplicate or unknown category names are ignored.
  /// Mutually exclusive with `categoryAllowList`.
  final List<String>? categoryDenylist;

  Pointer<bindings.ClassifierOptions> toStruct() {
    final struct = calloc<bindings.ClassifierOptions>();
    _setDisplayNamesLocale(struct.ref);
    _setMaxResults(struct.ref);
    _setScoreThreshold(struct.ref);
    _setAllowlist(struct.ref);
    _setDenylist(struct.ref);
    return struct;
  }

  void _setDisplayNamesLocale(bindings.ClassifierOptions struct) {
    if (displayNamesLocale != null) {
      struct.display_names_locale = prepareString(displayNamesLocale!);
    }
  }

  void _setMaxResults(bindings.ClassifierOptions struct) {
    // This value must not be zero, and -1 implies no limit.
    struct.max_results = maxResults ?? -1;
  }

  void _setScoreThreshold(bindings.ClassifierOptions struct) {
    if (scoreThreshold != null) {
      struct.score_threshold = scoreThreshold!;
    }
  }

  void _setAllowlist(bindings.ClassifierOptions struct) {
    if (categoryAllowlist != null) {
      struct.category_allowlist = prepareListOfStrings(categoryAllowlist!);
      struct.category_allowlist_count = categoryAllowlist!.length;
    }
  }

  void _setDenylist(bindings.ClassifierOptions struct) {
    if (categoryDenylist != null) {
      struct.category_denylist = prepareListOfStrings(categoryDenylist!);
      struct.category_denylist_count = categoryDenylist!.length;
    }
  }

  @override
  List<Object?> get props => [
        displayNamesLocale,
        maxResults,
        scoreThreshold,
        ...(categoryAllowlist ?? []),
        ...(categoryDenylist ?? []),
      ];
}
