// // Copyright 2014 The Flutter Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.

// import 'dart:async';
// import 'dart:ffi';
// import 'dart:math';

// import 'package:logging/logging.dart';
// import 'package:mediapipe_genai/mediapipe_genai.dart';

// final _log = Logger('FakeInferenceEngine');

// class FakeInferenceEngine implements LlmInferenceEngine {
//   FakeInferenceEngine(LlmInferenceOptions options) {
//     _log.info('Initializing FakeInferenceEngine with $options');
//   }

//   @override
//   Stream<String> generateResponse(String text) {
//     final controller = StreamController<String>.broadcast();

//     final rnd = Random();
//     // Delay between 500 and 1000ms
//     Future.delayed(Duration(milliseconds: rnd.nextInt(500) + 500)).then(
//       (_) async {
//         final List<String> message =
//             _genericResponses[rnd.nextInt(_genericResponses.length)];

//         for (final chunk in message) {
//           // Delay between 500 and 1000ms
//           await Future.delayed(Duration(milliseconds: rnd.nextInt(500) + 500));
//           controller.add(chunk);
//         }
//         controller.close();
//       },
//     );

//     return controller.stream;
//   }

//   @override
//   Future<int> sizeInTokens(String text) async =>
//       (text.split(' ').length * 1.5).toInt();

//   // These three methods, `cancel`, `dispose`, and `handleErrorMessage` serve
//   // no purpose whatsoever for this fake implementation and should not be
//   // necessary to implement here; but surprisingly the type system won't compile
//   // if they aren't present. Strangely, the analysis server does not report any
//   // issue, so the (false positive, I believe) error only arises when you run
//   // the actual app.
//   void cancel() => throw UnimplementedError();

//   @override
//   void dispose() => throw UnimplementedError();

//   void handleErrorMessage(Pointer<Pointer<Char>> errorMessage, [int? status]) =>
//       throw UnimplementedError();
// }

// const _genericResponses = <List<String>>[
//   ['Hello', 'my good', 'friend!', 'How are you doing?', 'Are you well?'],
//   ['Well now, don\'t', 'get so hasty! There are still reasonable', 'options.'],
//   ['From what I\'m hearing,', 'it sounds like you need to dance more.'],
//   [
//     'I too enjoy a nice sandwich,',
//     'but you\'ve gotta',
//     'toast the bread - come',
//     'on!',
//   ],
//   ['I don\'t appreciate that slander and', 'I own\'t', 'stand for it!'],
// ];
