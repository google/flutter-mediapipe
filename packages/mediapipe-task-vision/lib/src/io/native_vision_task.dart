import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show checkNativeStatus, nativeString, nativeStrings;
import 'package:mediapipe_core/platform_interface.dart'
    show ClassifierSettings, mpHostVersion, nativeModelPath;

import '../runner/native_interface.dart' show VisionTaskInput;
import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../types/results.dart';
import '../types/vision_types.dart';
import 'native_desktop_runtime.dart';
import 'native_vision_image.dart';

/// Initialize the shared base options with owned model bytes or a model path.
///
/// [officialGpu] marks a task whose GPU path is validated on Google's official
/// Linux, iOS and Android too; other tasks allow GPU on macOS only.
void setVisionBaseOptions(
  Arena arena,
  mp.MpBaseOptions base,
  VisionTaskOptions options, {
  bool officialGpu = false,
}) {
  if (options.delegate == Delegate.gpu &&
      !Platform.isMacOS &&
      !(officialGpu &&
          (Platform.isLinux || Platform.isIOS || Platform.isAndroid))) {
    throw UnsupportedError(
      officialGpu
          ? 'GPU vision inference requires macOS, Linux, iOS or Android.'
          : 'GPU vision inference is validated on macOS only.',
    );
  }
  loadOfficialDesktopRuntime();
  base.file_descriptor = -1;
  base.delegate = options.delegate == Delegate.gpu
      ? mp.MpDelegate.MP_DELEGATE_GPU
      : mp.MpDelegate.MP_DELEGATE_CPU;
  base.host_environment = mp.MpHostEnvironment.MP_HOST_ENVIRONMENT_FLUTTER;
  base.host_system = Platform.isLinux
      ? mp.MpHostSystem.MP_HOST_SYSTEM_LINUX
      : Platform.isWindows
      ? mp.MpHostSystem.MP_HOST_SYSTEM_WINDOWS
      : Platform.isIOS
      ? mp.MpHostSystem.MP_HOST_SYSTEM_IOS
      : Platform.isAndroid
      ? mp.MpHostSystem.MP_HOST_SYSTEM_ANDROID
      : mp.MpHostSystem.MP_HOST_SYSTEM_MAC;
  base.host_version = mpHostVersion.toNativeUtf8(allocator: arena).cast();
  if (options.modelPath case final path?) {
    base.model_asset_path = nativeModelPath(
      path,
    ).toNativeUtf8(allocator: arena).cast();
  }
  if (options.modelBytes case final bytes?) {
    final buffer = arena<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    base.model_asset_buffer = buffer.cast();
    base.model_asset_buffer_count = bytes.length;
  }
}

/// Convert the public running mode into the native task enum. LIVE_STREAM
/// runs on Google's VIDEO graph, with its flow limiter in the task runner.
mp.MpRunningMode nativeRunningMode(RunningMode mode) =>
    mode == RunningMode.image
    ? mp.MpRunningMode.MP_RUNNING_MODE_IMAGE
    : mp.MpRunningMode.MP_RUNNING_MODE_VIDEO;

/// Populate native rotation and optional normalized region of interest.
Pointer<mp.MpImageProcessingOptions> visionProcessingOptions(
  Arena arena,
  int rotation,
  VisionRegionOfInterest? region,
) {
  final options = arena<mp.MpImageProcessingOptions>();
  options.ref.rotation_degrees = rotation;
  if (region != null) {
    options.ref.has_region_of_interest = 1;
    options.ref.region_of_interest
      ..left = region.left
      ..top = region.top
      ..right = region.right
      ..bottom = region.bottom;
  }
  return options;
}

/// Copy native category labels and scores before closing the result.
MediaPipeCategory copyVisionCategory(mp.MpCategory category) =>
    MediaPipeCategory(
      index: category.index,
      score: category.score,
      categoryName: nativeString(category.category_name, emptyIsNull: true),
      displayName: nativeString(category.display_name, emptyIsNull: true),
    );

/// Copy every head and category into immutable Dart values.
List<Classifications> copyVisionClassifications(
  mp.MpClassificationResult result,
) => [
  for (var i = 0; i < result.classifications_count; i++)
    Classifications(
      headIndex: result.classifications[i].head_index,
      headName: nativeString(
        result.classifications[i].head_name,
        emptyIsNull: true,
      ),
      categories: [
        for (var j = 0; j < result.classifications[i].categories_count; j++)
          copyVisionCategory(result.classifications[i].categories[j]),
      ],
    ),
];

/// Copy a native embedding, preserving quantized bytes without sign conversion.
Embedding copyVisionEmbedding(mp.MpEmbedding value) => Embedding(
  headIndex: value.head_index,
  headName: nativeString(value.head_name, emptyIsNull: true),
  floatEmbedding: value.float_embedding == nullptr
      ? null
      : value.float_embedding.asTypedList(value.values_count),
  quantizedEmbedding: value.quantized_embedding == nullptr
      ? null
      : value.quantized_embedding.cast<Uint8>().asTypedList(value.values_count),
);

/// What a request's copy step reads: the arena that owns the request's native
/// memory, the image Google ran (for its size) and the frame's timestamp, null
/// for IMAGE requests.
typedef VisionRequest = ({Arena arena, mp.MpImagePtr image, int? timestamp});

/// Runs one IMAGE or VIDEO request, as [input]'s timestamp says, and returns
/// what [copy] makes of the result before Google's memory is released.
///
/// [allocate] takes the task's result struct from the request's arena (FFI
/// needs its concrete type); [image] and [video] are the task's two calls,
/// with the task bound; [closeResult] releases what Google wrote into the
/// result. Only tasks that accept a region of interest set [region].
R runVisionRequest<T extends Struct, R>(
  VisionTaskInput input, {
  required bool gpu,
  required Pointer<T> Function(Arena arena) allocate,
  required mp.MpStatus Function(
    mp.MpImagePtr image,
    Pointer<mp.MpImageProcessingOptions> processing,
    Pointer<T> result,
    Pointer<Pointer<Char>> error,
  )
  image,
  required mp.MpStatus Function(
    mp.MpImagePtr image,
    Pointer<mp.MpImageProcessingOptions> processing,
    int timestamp,
    Pointer<T> result,
    Pointer<Pointer<Char>> error,
  )
  video,
  required void Function(Pointer<T> result) closeResult,
  required R Function(VisionRequest request, Pointer<T> result) copy,
  bool region = false,
}) => using((arena) {
  final (source, rotation, timestamp, roi) = input;
  final native = createVisionImage(
    arena,
    source,
    expandRgbForGpu: gpu,
    checked: checkVisionCall,
  );
  try {
    final processing = visionProcessingOptions(
      arena,
      rotation,
      region ? roi : null,
    );
    final result = allocate(arena);
    if (timestamp == null) {
      checkVisionCall((error) => image(native, processing, result, error));
    } else {
      checkVisionCall(
        (error) => video(native, processing, timestamp, result, error),
      );
    }
    try {
      return copy((arena: arena, image: native, timestamp: timestamp), result);
    } finally {
      // This releases the contents, while the arena owns the outer struct.
      closeResult(result);
    }
  } finally {
    mp.MpImageFree(native);
  }
});

/// Copy a detection's box, categories and any keypoints.
Detection copyVisionDetection(mp.MpDetection value) => Detection(
  boundingBox: BoundingBox(
    left: value.bounding_box.left,
    top: value.bounding_box.top,
    right: value.bounding_box.right,
    bottom: value.bounding_box.bottom,
  ),
  categories: [
    for (var i = 0; i < value.categories_count; i++)
      copyVisionCategory(value.categories[i]),
  ],
  keypoints: [
    for (var i = 0; i < value.keypoints_count; i++)
      NormalizedKeypoint(
        x: value.keypoints[i].x,
        y: value.keypoints[i].y,
        label: nativeString(value.keypoints[i].label, emptyIsNull: true),
        score: value.keypoints[i].has_score ? value.keypoints[i].score : null,
      ),
  ],
);

/// Release native errors and throw an owned diagnostic on non-OK status.
void checkVisionCall(mp.MpStatus Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus((error) => call(error).value, mp.MpErrorFree);

/// Create a task, marking Google's GPU refusals (no EGL display, a software
/// renderer) so callers can choose CPU. The package never retries itself.
void checkVisionCreate(
  mp.MpStatus Function(Pointer<Pointer<Char>>) call, {
  required bool gpu,
}) {
  try {
    checkVisionCall(call);
  } on TaskException catch (error) {
    // Google's runtime reports every GPU refusal as its missing GPU service.
    if (!gpu || !error.message.contains('kGpuService')) rethrow;
    throw TaskException(
      error.message,
      statusCode: error.statusCode,
      gpuUnavailable: true,
    );
  }
}

/// Own every category in each subject's classification result.
///
/// [index] overrides the native index for heads whose raw value carries no
/// meaning, matching how the official bindings report them.
List<List<MediaPipeCategory>> copyVisionCategories(
  Pointer<mp.MpCategories> values,
  int count, {
  int? index,
}) => [
  for (var i = 0; i < count; i++)
    [
      for (var j = 0; j < values[i].categories_count; j++)
        if (index == null)
          copyVisionCategory(values[i].categories[j])
        else
          MediaPipeCategory(
            index: index,
            score: values[i].categories[j].score,
            categoryName: nativeString(
              values[i].categories[j].category_name,
              emptyIsNull: true,
            ),
            displayName: nativeString(
              values[i].categories[j].display_name,
              emptyIsNull: true,
            ),
          ),
    ],
];

/// Own normalized landmarks including optional confidence metadata.
List<NormalizedLandmark> copyVisionNormalizedLandmarks(
  mp.MpNormalizedLandmarks values,
) => [
  for (var i = 0; i < values.landmarks_count; i++)
    NormalizedLandmark(
      x: values.landmarks[i].x,
      y: values.landmarks[i].y,
      z: values.landmarks[i].z,
      visibility: values.landmarks[i].has_visibility
          ? values.landmarks[i].visibility
          : null,
      presence: values.landmarks[i].has_presence
          ? values.landmarks[i].presence
          : null,
      name: nativeString(values.landmarks[i].name, emptyIsNull: true),
    ),
];

/// Own world landmarks including optional confidence metadata.
List<Landmark> copyVisionWorldLandmarks(mp.MpLandmarks values) => [
  for (var i = 0; i < values.landmarks_count; i++)
    Landmark(
      x: values.landmarks[i].x,
      y: values.landmarks[i].y,
      z: values.landmarks[i].z,
      visibility: values.landmarks[i].has_visibility
          ? values.landmarks[i].visibility
          : null,
      presence: values.landmarks[i].has_presence
          ? values.landmarks[i].presence
          : null,
      name: nativeString(values.landmarks[i].name, emptyIsNull: true),
    ),
];

/// Read and copy a single-channel float32 mask, including padded native rows.
ConfidenceMask copyVisionConfidenceMask(Arena arena, mp.MpImagePtr image) {
  final width = mp.MpImageGetWidth(image);
  final height = mp.MpImageGetHeight(image);
  if (width < 1 ||
      height < 1 ||
      mp.MpImageGetChannels(image) != 1 ||
      mp.MpImageGetByteDepth(image) != 4) {
    throw const TaskException(
      'Native result is not a float32 confidence mask.',
    );
  }
  final data = arena<Pointer<Float>>();
  checkVisionCall((error) => mp.MpImageDataFloat32(image, data, error));
  if (data.value == nullptr) {
    throw const TaskException('Native mask data is missing.');
  }
  return ConfidenceMask(
    width: width,
    height: height,
    confidence: data.value.asTypedList(width * height),
  );
}

/// Read and copy a category mask, one class index per pixel.
///
/// Google's accessor returns padded rows as one contiguous copy. Its CPU
/// path returns uint8 classes, but its OpenGL ES postprocessing (Android and
/// Linux GPUs) renders one float32 channel holding each class divided by
/// 255 (a one-class model's 0 or 255 as 0.0 or 1.0), which is rounded back
/// to the class here.
CategoryMask copyVisionCategoryMask(Arena arena, mp.MpImagePtr image) {
  final width = mp.MpImageGetWidth(image);
  final height = mp.MpImageGetHeight(image);
  final channels = mp.MpImageGetChannels(image);
  final depth = mp.MpImageGetByteDepth(image);
  if (width < 1 || height < 1 || channels != 1 || (depth != 1 && depth != 4)) {
    throw TaskException(
      'Native category mask has $channels channel(s) of $depth byte(s) at '
      '${width}x$height; expected one uint8 or float32 channel.',
    );
  }
  if (depth == 4) {
    final data = arena<Pointer<Float>>();
    checkVisionCall((error) => mp.MpImageDataFloat32(image, data, error));
    if (data.value == nullptr) {
      throw const TaskException('Native mask data is missing.');
    }
    final values = data.value.asTypedList(width * height);
    final categories = Uint8List(values.length);
    for (var i = 0; i < values.length; i++) {
      categories[i] = (values[i] * 255).round().clamp(0, 255);
    }
    return CategoryMask(width: width, height: height, categories: categories);
  }
  final data = arena<Pointer<Uint8>>();
  checkVisionCall((error) => mp.MpImageDataUint8(image, data, error));
  if (data.value == nullptr) {
    throw const TaskException('Native mask data is missing.');
  }
  return CategoryMask(
    width: width,
    height: height,
    categories: data.value.asTypedList(width * height),
  );
}

/// Own every mask and quality score in a segmentation result.
ImageSegmenterResult copyVisionSegmentation(
  Arena arena,
  mp.MpImageSegmenterResult result,
  mp.MpImagePtr image,
  int? timestamp, {
  List<String> labels = const [],
}) => ImageSegmenterResult(
  labels: labels,
  confidenceMasks: result.confidence_masks_count == 0
      ? null
      : [
          for (var i = 0; i < result.confidence_masks_count; i++)
            copyVisionConfidenceMask(arena, result.confidence_masks[i]),
        ],
  categoryMask: result.has_category_mask == 0
      ? null
      : copyVisionCategoryMask(arena, result.category_mask),
  qualityScores: result.quality_scores == nullptr
      ? null
      : result.quality_scores.asTypedList(result.quality_scores_count),
  imageWidth: mp.MpImageGetWidth(image),
  imageHeight: mp.MpImageGetHeight(image),
  timestampMilliseconds: timestamp,
);

/// Populate native classification filters: Image Classifier's, and Gesture
/// Recognizer's canned and custom ones.
void setVisionClassifierOptions(
  Arena arena,
  mp.MpClassifierOptions output,
  ClassifierSettings options,
) {
  output
    ..max_results = options.maxResults
    ..score_threshold = options.scoreThreshold
    ..category_allowlist = nativeStrings(arena, options.categoryAllowlist)
    ..category_allowlist_count = options.categoryAllowlist.length
    ..category_denylist = nativeStrings(arena, options.categoryDenylist)
    ..category_denylist_count = options.categoryDenylist.length;
  if (options.displayNamesLocale case final locale?) {
    output.display_names_locale = locale.toNativeUtf8(allocator: arena).cast();
  }
}
