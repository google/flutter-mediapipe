import 'dart:ui';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import 'image_classifier.dart';
import 'containers/containers.dart';
import '../../../third_party/mediapipe/mediapipe_vision_bindings.dart'
    as bindings;

final _log = Logger('ImageClassifier');

/// Channel to analyze images via MediaPipe's vision classification task.
class ImageClassifier extends BaseImageClassifier {
  /// Generative constructor which creates an [ImageClassifer] instance.
  ImageClassifier({required super.options});

  @override
  Future<ImageClassifierResult> classify(Image image) async {
    final optionsPtr = options.toStruct();

    // TODO(craiglabenz): What is the correct value to pass to this initializer?
    // Maybe it should be 0?
    final initError = calloc<Pointer<Char>>(1);

    final classifierPtr =
        bindings.image_classifier_create(optionsPtr, initError);
    _log.finest('classifierPtr: $classifierPtr');

    if (classifierPtr.address == 0) {
      throw Exception(
        'Configuration error:\n${_flattenErrors(initError)}',
      );
    }
    calloc.free(initError);

    // Allocate the container for our results
    final resultsPtr = calloc<bindings.ImageClassifierResult>();
    final classifyError = calloc<Pointer<Char>>(1);

    int result = bindings.image_classifier_classify_image(
      classifierPtr,
      toImageStruct(image),
      resultsPtr,
      classifyError,
    );
    if (result == 0) {
      // Failure
      throw Exception(
        'Classification error:\n${_flattenErrors(classifyError)}',
      );
    } else {
      // Success
      return ImageClassifierResult.fromStruct(resultsPtr.ref);
    }
  }

  /// Converts a Dart [Image] into the MediaPipe representation of an image.
  Pointer<bindings.MpImage> toImageStruct(Image img) {
    // TODO(craiglabenz): Implement
    throw UnimplementedError('Implement `toImageStruct`');
  }

  String _flattenErrors(Pointer<Pointer<Char>> errors) {
    final errorMessages = toDartStrings(errors);
    final flattenedError =
        errorMessages.where((String? val) => val != null).join('\n');
    calloc.free(errors);
    return flattenedError;
  }
}
