// // Copyright 2014 The Flutter Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.

// import 'dart:ffi' as ffi;
// import 'dart:ffi';
// import 'package:ffi/ffi.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:mediapipe_core/mediapipe_core.dart' as core;
// import 'package:mediapipe_text/mediapipe_text.dart' as text;

// // ignore: implementation_imports
// import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart';
// import 'third_party/mediapipe/generated/mediapipe_text_bindings.dart';

// part 'text_task_message.freezed.dart';

// @Freezed(fromJson: false, toJson: false)
// class TextTaskWorker with _$TextTaskWorker {
//   const TextTaskWorker._();
//   const factory TextTaskWorker.textClassification(
//     Pointer<TextClassifierOptions> options,
//   ) = TextClassificationWorker;
//   const factory TextTaskWorker.textEmbedding(
//     Pointer<TextEmbedderOptions> options,
//   ) = TextEmbeddingWorker;

//   ffi.Pointer<ffi.Void> create(Pointer<Pointer<Char>> errorMsg) {
//     return map<ffi.Pointer<ffi.Void>>(
//       textClassification: (msg) => text_classifier_create(
//         options as Pointer<TextClassifierOptions>,
//         errorMsg,
//       ),
//       textEmbedding: (msg) => text_embedder_create(
//         options as Pointer<TextEmbedderOptions>,
//         errorMsg,
//       ),
//     );
//   }
// }

// /// Container for parameters to text-based MediaPipe tasks.
// @Freezed(fromJson: false, toJson: false)
// class TextTaskMessage extends core.TaskMessage with _$TextTaskMessage {
//   const TextTaskMessage._();
//   const factory TextTaskMessage.textClassification(String text) =
//       TextClassificationMessage;
//   const factory TextTaskMessage.textEmbedding(String text) =
//       TextEmbeddingMessage;
//   const factory TextTaskMessage.cosineSimilarity(
//       Pointer<Embedding> a, Pointer<Embedding> b) = CosineSimilarityMessage;

//   Pointer<NativeType> createResultsPointer() => map<Pointer<NativeType>>(
//         textClassification: (_) => calloc<TextClassifierResult>(),
//         textEmbedding: (_) => calloc<TextEmbedderResult>(),
//         cosineSimilarity: (_) => calloc<Double>(),
//       );

//   void releaseResults(Pointer<NativeType> results) => map<void>(
//         textClassification: (_) => (results as text.TextClassifierResult)
//             .free(results as Pointer<TextClassifierResult>),
//         textEmbedding: (_) => (results as text.TextEmbedderResult)
//             .free(results as Pointer<TextEmbedderResult>),
//         cosineSimilarity: (_) => calloc.free(results as Pointer<Double>),
//       );

//   Object resultsToDart(Pointer<NativeType> results) => map<Object>(
//         textClassification: (_) => text.TextClassifierResult.structToDart(
//             (results as Pointer<TextClassifierResult>).ref),
//         textEmbedding: (_) => text.TextEmbedderResult.structToDart(
//             (results as Pointer<TextEmbedderResult>).ref),
//         cosineSimilarity: (_) => (results as Pointer<Double>).value,
//       );

//   @override
//   int run(
//     ffi.Pointer<ffi.Void> worker,
//     ffi.Pointer<NativeType> result,
//     ffi.Pointer<ffi.Pointer<ffi.Char>> errorMsg,
//   ) =>
//       map<int>(
//         textClassification: (msg) => text_classifier_classify(
//           worker,
//           core.prepareString(msg.text),
//           result as ffi.Pointer<TextClassifierResult>,
//           errorMsg,
//         ),
//         textEmbedding: (msg) => text_embedder_embed(
//           worker,
//           core.prepareString(msg.text),
//           result as ffi.Pointer<TextEmbedderResult>,
//           errorMsg,
//         ),
//         cosineSimilarity: (msg) => text_embedder_cosine_similarity(
//           msg.a,
//           msg.b,
//           result as ffi.Pointer<Double>,
//           errorMsg,
//         ),
//       );
// }
