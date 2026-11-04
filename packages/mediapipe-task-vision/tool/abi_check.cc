// The C ABI sizes the vision bindings assume, checked against the vendored
// headers in mediapipe_core/native/include. `make test_vision` compiles it.
#include "components/containers/category.h"
#include "components/containers/keypoint.h"
#include "vision/core/image_processing_options.h"
#include "vision/face_detector/face_detector.h"
#include "vision/face_landmarker/face_landmarker.h"
#include "vision/interactive_segmenter/interactive_segmenter.h"

static_assert(sizeof(MpStatus) == 4);
static_assert(sizeof(MpImageFormat) == 4);
static_assert(sizeof(MpRunningMode) == 4);
static_assert(sizeof(MpBaseOptions) == 72);
static_assert(sizeof(MpFaceDetectorOptions) == 96);
static_assert(sizeof(MpDetectionResult) == 16);
static_assert(sizeof(MpDetection) == 48);
static_assert(sizeof(MpCategory) == 24);
static_assert(sizeof(MpNormalizedKeypoint) == 24);
static_assert(sizeof(MpImageProcessingOptions) == 24);
static_assert(sizeof(MpFaceLandmarkerOptions) == 104);
static_assert(sizeof(MpFaceLandmarkerResult) == 48);
static_assert(sizeof(MpNormalizedLandmark) == 40);
static_assert(sizeof(MpNormalizedLandmarks) == 16);
static_assert(sizeof(MpMatrix) == 16);
static_assert(sizeof(MpBrushMode) == 4);
static_assert(sizeof(MpInteractiveSegmenterOptions) == 72);
static_assert(sizeof(MpStrokePoint) == 8);
static_assert(sizeof(MpStroke) == 24);
static_assert(sizeof(MpStrokes) == 16);
