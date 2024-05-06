// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_model.freezed.dart';

enum Hardware { cpu, gpu }

enum LlmModel {
  gemma4bCpu,
  gemma4bGpu,
  gemma8bCpu,
  gemma8bGpu;

  Hardware get hardware => switch (this) {
        gemma4bCpu => Hardware.cpu,
        gemma4bGpu => Hardware.gpu,
        gemma8bCpu => Hardware.cpu,
        gemma8bGpu => Hardware.gpu,
      };

  String get dartDefine => switch (this) {
        gemma4bCpu => const String.fromEnvironment('GEMMA_4B_CPU_URI'),
        gemma4bGpu => const String.fromEnvironment('GEMMA_4B_GPU_URI'),
        gemma8bCpu => const String.fromEnvironment('GEMMA_8B_CPU_URI'),
        gemma8bGpu => const String.fromEnvironment('GEMMA_8B_GPU_URI'),
      };

  String get environmentVariableUriName => switch (this) {
        gemma4bCpu => 'GEMMA_4B_CPU_URI',
        gemma4bGpu => 'GEMMA_4B_GPU_URI',
        gemma8bCpu => 'GEMMA_8B_CPU_URI',
        gemma8bGpu => 'GEMMA_8B_GPU_URI',
      };

  String get displayName => switch (this) {
        gemma4bCpu => 'Gemma\n4b CPU',
        gemma4bGpu => 'Gemma\n4b GPU',
        gemma8bCpu => 'Gemma\n8b CPU',
        gemma8bGpu => 'Gemma\n8b GCPU',
      };
}

@Freezed()
class ModelInfo with _$ModelInfo {
  const ModelInfo._();
  const factory ModelInfo({
    /// Size of the on-disk location of this model. A null value here either
    /// means that the model is currently downloading or completely missing.
    int? downloadedBytes,

    /// 0-100 if a model is being downloaded. A null value here means no
    /// download is in progress for the given model.
    int? downloadPercent,

    /// Location of the model if it is available on disk.
    String? path,
  }) = _ModelInfo;

  ModelState get state {
    if (downloadedBytes != null) {
      return ModelState.downloaded;
    } else if (downloadPercent != null) {
      return ModelState.downloading;
    }
    return ModelState.empty;
  }
}

enum ModelState { downloaded, downloading, empty }
