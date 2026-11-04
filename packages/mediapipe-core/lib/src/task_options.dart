/// The one base every task's options extend, on every platform.
library;

import 'dart:typed_data';

import 'delegate.dart';
import 'download_asset.dart';
import 'model_source.dart';
import 'pinned_model.dart';

/// Model and delegate shared by every task's options, in every family.
///
/// Supply exactly one model source: a pinned official [model], a [modelPath]
/// or owned [modelBytes]. A task's `create` resolves a pinned model to the
/// app's bundled copy (or a download when `ModelStore.allowDownloads` is
/// true), checks it against its SHA-256, and only then opens Google's
/// runtime. The public values never change after construction.
abstract base class TaskOptions {
  /// Checks the model source and [delegate] once, the same way on every
  /// platform. `family` and `registry` (the family's `XxxModels.byName`) let
  /// an error for a model the app does not bundle name the pubspec entry.
  TaskOptions({
    this.model,
    String? modelPath,
    Uint8List? modelBytes,
    this.delegate = Delegate.cpu,
    required this._family,
    required this._registry,
  }) : _modelPath = modelPath,
       _modelBytes = modelBytes == null
           ? null
           : Uint8List.fromList(modelBytes).asUnmodifiableView() {
    if ([
          model,
          modelPath,
          modelBytes,
        ].where((source) => source != null).length !=
        1) {
      throw ArgumentError(
        'Supply exactly one of model, modelPath and modelBytes.',
      );
    }
    if (modelPath != null &&
        (modelPath.isEmpty || modelPath.contains('\u0000'))) {
      throw ArgumentError.value(modelPath, 'modelPath', 'Invalid path');
    }
    if (modelBytes != null &&
        (modelBytes.isEmpty || modelBytes.length > 0xffffffff)) {
      throw ArgumentError.value(
        modelBytes.length,
        'modelBytes',
        'Invalid model buffer size',
      );
    }
  }

  /// Pinned official model: the app's bundled copy, or a download when
  /// `ModelStore.allowDownloads` is true. Verified against its SHA-256.
  final DownloadAsset? model;

  /// The processor the task runs on, fixed until it is disposed.
  final Delegate delegate;

  final String _family;
  final Map<String, DownloadAsset> _registry;
  final String? _modelPath;
  final Uint8List? _modelBytes;
  ModelSource? _resolved;

  /// The model's location, as Google's APIs read it: a file on native
  /// platforms and a URL, resolved against the page, in browsers. Null when
  /// the model is in memory.
  String? get modelPath =>
      _heldBytes[this] == null ? _resolved?.path ?? _modelPath : null;

  /// Owned, read-only model bytes. Null when the model is a file.
  Uint8List? get modelBytes =>
      _heldBytes[this] ?? _resolved?.bytes ?? _modelBytes;
}

/// Model bytes a runtime holds for its own copy of a task's options, so it
/// can reopen Google's task after the app deletes the model file. While an
/// entry is set, the options' [TaskOptions.modelBytes] returns it and
/// [TaskOptions.modelPath] returns null.
final _heldBytes = Expando<Uint8List>('held model bytes');

/// Resolves a pinned [TaskOptions.model] before a task opens Google's runtime:
/// every task's `create` calls this first. A path or bytes need nothing.
Future<void> resolveTaskModel(TaskOptions options) async {
  if (options.model case final model?) {
    options._resolved = await resolvePinnedModel(
      model,
      family: options._family,
      registry: options._registry,
    );
  }
}

/// Keeps [bytes] as [options]' model, for a runtime that reopens its task
/// after the model file may be gone (see `GpuFrameBudget` in mediapipe_vision).
void holdModelBytes(TaskOptions options, Uint8List bytes) {
  _heldBytes[options] = bytes;
}
