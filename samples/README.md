# Samples

<!-- Written by tool/samples_index.py; do not edit. -->

Every Dart sample in the docs, one file per sample. Each file is the
doc's code block byte for byte: change both together, then run
`python3 -B tool/samples_index.py` and `python3 -B tool/check_docs.py`
(it fails, naming the doc and line, on any difference).

A dash in Modes is a mode the task offers that has no sample yet.
Platforms come from the coverage matrix (`tool/coverage/matrix.json`).
The runnable object detection app is in
[apps/object_detection](apps/object_detection/).

## vision

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| common |  | [browser_overlay (web only)](vision/common/browser_overlay.dart), [capabilities](vision/common/capabilities.dart) |  |  |  |  |  |  |
| face_detector | [image](vision/face_detector/image.dart), [video](vision/face_detector/video.dart), [live_stream](vision/face_detector/live_stream.dart) | [rgb_pixels](vision/face_detector/rgb_pixels.dart) | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU | CPU |
| face_landmarker | [image](vision/face_landmarker/image.dart), [video](vision/face_landmarker/video.dart), [live_stream](vision/face_landmarker/live_stream.dart) | [count_faces](vision/face_landmarker/count_faces.dart), [expressions_image](vision/face_landmarker/expressions_image.dart), [expressions_live_stream](vision/face_landmarker/expressions_live_stream.dart), [expressions_video](vision/face_landmarker/expressions_video.dart), [gpu](vision/face_landmarker/gpu.dart), [model_from_asset](vision/face_landmarker/model_from_asset.dart), [transformation_matrixes](vision/face_landmarker/transformation_matrixes.dart) | CPU, GPU | CPU, GPU | CPU (GPU planned) | CPU | CPU, GPU | CPU |
| gesture_recognizer | [image](vision/gesture_recognizer/image.dart), [video](vision/gesture_recognizer/video.dart), [live_stream](vision/gesture_recognizer/live_stream.dart) |  | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU | CPU |
| hand_landmarker | [image](vision/hand_landmarker/image.dart), [video](vision/hand_landmarker/video.dart), [live_stream](vision/hand_landmarker/live_stream.dart) |  | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU | CPU |
| holistic_landmarker | [image](vision/holistic_landmarker/image.dart), [video](vision/holistic_landmarker/video.dart), [live_stream](vision/holistic_landmarker/live_stream.dart) | [mask_and_blendshapes](vision/holistic_landmarker/mask_and_blendshapes.dart) | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU | CPU |
| image_classifier | [image](vision/image_classifier/image.dart), [video](vision/image_classifier/video.dart), [live_stream](vision/image_classifier/live_stream.dart) | [region_of_interest](vision/image_classifier/region_of_interest.dart) | CPU, GPU | CPU, GPU | CPU (GPU planned) | CPU | CPU, GPU | CPU |
| image_embedder | [image](vision/image_embedder/image.dart), [video](vision/image_embedder/video.dart), [live_stream](vision/image_embedder/live_stream.dart) | [quantized](vision/image_embedder/quantized.dart) | CPU, GPU | CPU, GPU | CPU (GPU planned) | CPU | CPU | CPU |
| image_segmenter | [image](vision/image_segmenter/image.dart), [video](vision/image_segmenter/video.dart), [live_stream](vision/image_segmenter/live_stream.dart) | [confidence_masks](vision/image_segmenter/confidence_masks.dart) | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU, GPU | CPU |
| interactive_segmenter | [image](vision/interactive_segmenter/image.dart) |  | CPU, GPU | CPU | CPU | CPU | CPU | no |
| object_detector | [image](vision/object_detector/image.dart), [video](vision/object_detector/video.dart), [live_stream](vision/object_detector/live_stream.dart) | [guide/create_image](vision/object_detector/guide/create_image.dart), [guide/create_live_stream](vision/object_detector/guide/create_live_stream.dart), [guide/create_video](vision/object_detector/guide/create_video.dart), [guide/input_image](vision/object_detector/guide/input_image.dart), [guide/input_live_stream](vision/object_detector/guide/input_live_stream.dart), [guide/input_video](vision/object_detector/guide/input_video.dart), [guide/results](vision/object_detector/guide/results.dart), [guide/run_image](vision/object_detector/guide/run_image.dart), [guide/run_live_stream](vision/object_detector/guide/run_live_stream.dart), [guide/run_video](vision/object_detector/guide/run_video.dart) | CPU, GPU | CPU, GPU | CPU (GPU planned) | CPU | CPU, GPU | CPU |
| pose_landmarker | [image](vision/pose_landmarker/image.dart), [video](vision/pose_landmarker/video.dart), [live_stream](vision/pose_landmarker/live_stream.dart) | [segmentation_masks](vision/pose_landmarker/segmentation_masks.dart) | CPU, GPU | CPU | CPU (GPU planned) | CPU | CPU | CPU |

## audio

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| audio_classifier | [clip](audio/audio_classifier/clip.dart), [stream](audio/audio_classifier/stream.dart) | [capabilities](audio/audio_classifier/capabilities.dart) | CPU | CPU | CPU | CPU | CPU | CPU |
| audio_transcriber | [clip](audio/audio_transcriber/clip.dart), [stream](audio/audio_transcriber/stream.dart) | [prewarm](audio/audio_transcriber/prewarm.dart) | CPU, GPU | CPU | CPU (GPU planned) | CPU, GPU | CPU | CPU |
| text_to_speech | [utterance](audio/text_to_speech/utterance.dart), [stream](audio/text_to_speech/stream.dart) |  | CPU | CPU | CPU | CPU, GPU | CPU | CPU |

## text

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| common |  | [capabilities](text/common/capabilities.dart) |  |  |  |  |  |  |
| language_detector |  | [detect](text/language_detector/detect.dart) | CPU | CPU | CPU | CPU | CPU | CPU |
| text_classifier |  | [classify](text/text_classifier/classify.dart), [top_category](text/text_classifier/top_category.dart) | CPU | CPU | CPU | CPU | CPU | CPU |
| text_embedder |  | [embed](text/text_embedder/embed.dart) | CPU | CPU | CPU | CPU | CPU | CPU |
| text_embedder (embedding_gemma model) |  | [question_answering](text/text_embedder/question_answering.dart), [semantic_similarity](text/text_embedder/semantic_similarity.dart) | CPU | CPU | CPU | CPU | CPU | CPU |
| text_proofreader |  | [proofread](text/text_proofreader/proofread.dart) | no | CPU | CPU | CPU | CPU | CPU |
| text_summarizer |  | [capabilities](text/text_summarizer/capabilities.dart), [key_points](text/text_summarizer/key_points.dart), [summarize](text/text_summarizer/summarize.dart) | no | CPU | CPU | CPU | CPU | CPU |

## retrieval

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| semantic_retriever | [text](retrieval/semantic_retriever/text.dart), [image](retrieval/semantic_retriever/image.dart), [audio_and_content](retrieval/semantic_retriever/audio_and_content.dart) | [manage_records](retrieval/semantic_retriever/manage_records.dart), [persistent_database](retrieval/semantic_retriever/persistent_database.dart) | no | CPU | CPU | CPU | CPU | CPU |
| universal_embedder | text: -, [image](retrieval/universal_embedder/image.dart), [audio](retrieval/universal_embedder/audio.dart) |  | no | CPU | CPU | CPU | CPU | CPU |

## decision

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| decision_maker | [single](decision/decision_maker/single.dart), [batch](decision/decision_maker/batch.dart) |  | no | CPU | CPU | CPU | CPU | CPU |

## core

| Task | Modes | Other samples | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| model_store |  | [clear](core/model_store/clear.dart), [prefetch](core/model_store/prefetch.dart) |  |  |  |  |  |  |
| web_runtime |  | [self_hosted](core/web_runtime/self_hosted.dart) |  |  |  |  |  |  |

## Where each sample appears

| Sample | Docs |
| --- | --- |
| [audio/audio_classifier/capabilities.dart](audio/audio_classifier/capabilities.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/audio_classifier/clip.dart](audio/audio_classifier/clip.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/audio_classifier/stream.dart](audio/audio_classifier/stream.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/audio_transcriber/clip.dart](audio/audio_transcriber/clip.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/audio_transcriber/prewarm.dart](audio/audio_transcriber/prewarm.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/audio_transcriber/stream.dart](audio/audio_transcriber/stream.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/text_to_speech/stream.dart](audio/text_to_speech/stream.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [audio/text_to_speech/utterance.dart](audio/text_to_speech/utterance.dart) | [packages/mediapipe-task-audio/README.md](../packages/mediapipe-task-audio/README.md) |
| [core/model_store/clear.dart](core/model_store/clear.dart) | [doc/mediapipe_core.md](../doc/mediapipe_core.md) |
| [core/model_store/prefetch.dart](core/model_store/prefetch.dart) | [doc/mediapipe_core.md](../doc/mediapipe_core.md) |
| [core/web_runtime/self_hosted.dart](core/web_runtime/self_hosted.dart) | [doc/mediapipe_core.md](../doc/mediapipe_core.md) |
| [decision/decision_maker/batch.dart](decision/decision_maker/batch.dart) | [packages/mediapipe-task-decision/README.md](../packages/mediapipe-task-decision/README.md) |
| [decision/decision_maker/single.dart](decision/decision_maker/single.dart) | [packages/mediapipe-task-decision/README.md](../packages/mediapipe-task-decision/README.md) |
| [retrieval/semantic_retriever/audio_and_content.dart](retrieval/semantic_retriever/audio_and_content.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/semantic_retriever/image.dart](retrieval/semantic_retriever/image.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/semantic_retriever/manage_records.dart](retrieval/semantic_retriever/manage_records.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/semantic_retriever/persistent_database.dart](retrieval/semantic_retriever/persistent_database.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/semantic_retriever/text.dart](retrieval/semantic_retriever/text.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/universal_embedder/audio.dart](retrieval/universal_embedder/audio.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [retrieval/universal_embedder/image.dart](retrieval/universal_embedder/image.dart) | [packages/mediapipe-task-retrieval/README.md](../packages/mediapipe-task-retrieval/README.md) |
| [text/common/capabilities.dart](text/common/capabilities.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/language_detector/detect.dart](text/language_detector/detect.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_classifier/classify.dart](text/text_classifier/classify.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_classifier/top_category.dart](text/text_classifier/top_category.dart) | [MIGRATION.md](../MIGRATION.md) |
| [text/text_embedder/embed.dart](text/text_embedder/embed.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_embedder/question_answering.dart](text/text_embedder/question_answering.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_embedder/semantic_similarity.dart](text/text_embedder/semantic_similarity.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_proofreader/proofread.dart](text/text_proofreader/proofread.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_summarizer/capabilities.dart](text/text_summarizer/capabilities.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_summarizer/key_points.dart](text/text_summarizer/key_points.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [text/text_summarizer/summarize.dart](text/text_summarizer/summarize.dart) | [packages/mediapipe-task-text/README.md](../packages/mediapipe-task-text/README.md) |
| [vision/common/browser_overlay.dart](vision/common/browser_overlay.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/common/capabilities.dart](vision/common/capabilities.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/face_detector/image.dart](vision/face_detector/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_detector/live_stream.dart](vision/face_detector/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/face_detector/rgb_pixels.dart](vision/face_detector/rgb_pixels.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/face_detector/video.dart](vision/face_detector/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/face_landmarker/count_faces.dart](vision/face_landmarker/count_faces.dart) | [README.md](../README.md), [packages/mediapipe-core/README.md](../packages/mediapipe-core/README.md) |
| [vision/face_landmarker/expressions_image.dart](vision/face_landmarker/expressions_image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_landmarker/expressions_live_stream.dart](vision/face_landmarker/expressions_live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/face_landmarker/expressions_video.dart](vision/face_landmarker/expressions_video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/face_landmarker/gpu.dart](vision/face_landmarker/gpu.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_landmarker/image.dart](vision/face_landmarker/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_landmarker/live_stream.dart](vision/face_landmarker/live_stream.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_landmarker/model_from_asset.dart](vision/face_landmarker/model_from_asset.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/face_landmarker/transformation_matrixes.dart](vision/face_landmarker/transformation_matrixes.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/face_landmarker/video.dart](vision/face_landmarker/video.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/gesture_recognizer/image.dart](vision/gesture_recognizer/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/gesture_recognizer/live_stream.dart](vision/gesture_recognizer/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/gesture_recognizer/video.dart](vision/gesture_recognizer/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/hand_landmarker/image.dart](vision/hand_landmarker/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/hand_landmarker/live_stream.dart](vision/hand_landmarker/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/hand_landmarker/video.dart](vision/hand_landmarker/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/holistic_landmarker/image.dart](vision/holistic_landmarker/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/holistic_landmarker/live_stream.dart](vision/holistic_landmarker/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/holistic_landmarker/mask_and_blendshapes.dart](vision/holistic_landmarker/mask_and_blendshapes.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/holistic_landmarker/video.dart](vision/holistic_landmarker/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_classifier/image.dart](vision/image_classifier/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/image_classifier/live_stream.dart](vision/image_classifier/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_classifier/region_of_interest.dart](vision/image_classifier/region_of_interest.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/image_classifier/video.dart](vision/image_classifier/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_embedder/image.dart](vision/image_embedder/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/image_embedder/live_stream.dart](vision/image_embedder/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_embedder/quantized.dart](vision/image_embedder/quantized.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/image_embedder/video.dart](vision/image_embedder/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_segmenter/confidence_masks.dart](vision/image_segmenter/confidence_masks.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/image_segmenter/image.dart](vision/image_segmenter/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/image_segmenter/live_stream.dart](vision/image_segmenter/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/image_segmenter/video.dart](vision/image_segmenter/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/interactive_segmenter/image.dart](vision/interactive_segmenter/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/object_detector/guide/create_image.dart](vision/object_detector/guide/create_image.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/create_live_stream.dart](vision/object_detector/guide/create_live_stream.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/create_video.dart](vision/object_detector/guide/create_video.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/input_image.dart](vision/object_detector/guide/input_image.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/input_live_stream.dart](vision/object_detector/guide/input_live_stream.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/input_video.dart](vision/object_detector/guide/input_video.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/results.dart](vision/object_detector/guide/results.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/run_image.dart](vision/object_detector/guide/run_image.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/run_live_stream.dart](vision/object_detector/guide/run_live_stream.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/guide/run_video.dart](vision/object_detector/guide/run_video.dart) | [doc/guides/vision/object_detector.md](../doc/guides/vision/object_detector.md) |
| [vision/object_detector/image.dart](vision/object_detector/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/object_detector/live_stream.dart](vision/object_detector/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/object_detector/video.dart](vision/object_detector/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/pose_landmarker/image.dart](vision/pose_landmarker/image.dart) | [packages/mediapipe-task-vision/README.md](../packages/mediapipe-task-vision/README.md) |
| [vision/pose_landmarker/live_stream.dart](vision/pose_landmarker/live_stream.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
| [vision/pose_landmarker/segmentation_masks.dart](vision/pose_landmarker/segmentation_masks.dart) | [doc/guides/vision/options_and_outputs.md](../doc/guides/vision/options_and_outputs.md) |
| [vision/pose_landmarker/video.dart](vision/pose_landmarker/video.dart) | [doc/guides/vision/video_and_live_stream.md](../doc/guides/vision/video_and_live_stream.md) |
