/* Copyright 2023 The MediaPipe Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#ifndef MEDIAPIPE_TASKS_C_VISION_IMAGE_CLASSIFIER_IMAGE_CLASSIFIER_H_
#define MEDIAPIPE_TASKS_C_VISION_IMAGE_CLASSIFIER_IMAGE_CLASSIFIER_H_

#include <cstdint>

#include "../../../../../../mediapipe-core/third_party/mediapipe/tasks/c/components/containers/classification_result.h"
#include "../../../../../../mediapipe-core/third_party/mediapipe/tasks/c/components/processors/classifier_options.h"
#include "../../../../../../mediapipe-core/third_party/mediapipe/tasks/c/core/base_options.h"

#ifndef MP_EXPORT
#define MP_EXPORT __attribute__((visibility("default")))
#endif  // MP_EXPORT

#ifdef __cplusplus
extern "C" {
#endif

  typedef ClassificationResult ImageClassifierResult;

  // Supported image formats.
  enum ImageFormat {
    UNKNOWN = 0,
    SRGB = 1,
    SRGBA = 2,
    GRAY8 = 3,
    SBGRA = 11  // compatible with Flutter `bgra8888` format.
  };

  // Supported processing modes.
  enum RunningMode {
    IMAGE = 1,
    VIDEO = 2,
    LIVE_STREAM = 3,
  };

  // Structure to hold image frame.
  struct ImageFrame {
    enum ImageFormat format;
    const uint8_t* image_buffer;
    int width;
    int height;
  };

  // TODO: Add GPU buffer declaration and proccessing logic for it.
  struct GpuBuffer {
    int height;
    int width;
  };

  // The object to contain an image, realizes `OneOf` concept.
  struct MpImage {
    enum { IMAGE_FRAME, GPU_BUFFER } type;
    union {
      struct ImageFrame image_frame;
      struct GpuBuffer gpu_buffer;
    };
  };

  // The options for configuring a Mediapipe image classifier task.
  struct ImageClassifierOptions {
    // Base options for configuring MediaPipe Tasks, such as specifying the model
    // file with metadata, accelerator options, op resolver, etc.
    struct BaseOptions base_options;

    // The running mode of the task. Default to the image mode.
    // Image classifier has three running modes:
    // 1) The image mode for classifying image on single image inputs.
    // 2) The video mode for classifying image on the decoded frames of a video.
    // 3) The live stream mode for classifying image on the live stream of input
    // data, such as from camera. In this mode, the "result_callback" below must
    // be specified to receive the segmentation results asynchronously.
    RunningMode running_mode;

    // Options for configuring the classifier behavior, such as score threshold,
    // number of results, etc.
    struct ClassifierOptions classifier_options;

    // The user-defined result callback for processing live stream data.
    // The result callback should only be specified when the running mode is set
    // to RunningMode::LIVE_STREAM.
    typedef void (*result_callback_fn)(ImageClassifierResult*, const MpImage*,
      int64_t);
    result_callback_fn result_callback;
  };

  // Creates an ImageClassifier from provided `options`.
  // Returns a pointer to the image classifier on success.
  // If an error occurs, returns `nullptr` and sets the error parameter to an
  // an error message (if `error_msg` is not nullptr). You must free the memory
  // allocated for the error message.
  MP_EXPORT void* image_classifier_create(struct ImageClassifierOptions* options,
    char** error_msg = nullptr);

  // Performs image classification on the input `image`. Returns `0` on success.
  // If an error occurs, returns an error code and sets the error parameter to an
  // an error message (if `error_msg` is not nullptr). You must free the memory
  // allocated for the error message.
  //
  // TODO: Add API for video and live stream processing.
  MP_EXPORT int image_classifier_classify_image(void* classifier,
    const MpImage* image,
    ImageClassifierResult* result,
    char** error_msg = nullptr);

  // Frees the memory allocated inside a ImageClassifierResult result.
  // Does not free the result pointer itself.
  MP_EXPORT void image_classifier_close_result(ImageClassifierResult* result);

  // Frees image classifier.
  // If an error occurs, returns an error code and sets the error parameter to an
  // an error message (if `error_msg` is not nullptr). You must free the memory
  // allocated for the error message.
  MP_EXPORT int image_classifier_close(void* classifier,
    char** error_msg = nullptr);

#ifdef __cplusplus
}  // extern C
#endif

#endif  // MEDIAPIPE_TASKS_C_VISION_IMAGE_CLASSIFIER_IMAGE_CLASSIFIER_H_
