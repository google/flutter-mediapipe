# Image Embedder samples

The gallery's Image Embedder page compares these photos, the three that
Google's own Image Embedding demo offers. They are copied unchanged from
[google-ai-edge/mediapipe-samples-web](https://github.com/google-ai-edge/mediapipe-samples-web/tree/0e0e059183983b4eb0e9316e00b0e2e937c8b11e/public)
at revision `0e0e059183983b4eb0e9316e00b0e2e937c8b11e`. That repository is
licensed under the Apache License 2.0, preserved in
[SOURCE_LICENSE](SOURCE_LICENSE).

| File | Source path | Size | SHA-256 |
| --- | --- | --- | --- |
| `dog.jpg` | `public/dog.jpg` | 640 x 640 | `87295aa79a9e285f86a94c58230c50401453dbc8cca946d544ce0e3de3f71cf7` |
| `cat.png` | `public/cat.png` | 640 x 640 | `e8383ad9f9be84a62cb18ae2be6d6d89e478663385bcec9ffe5d82f6db3fd4d5` |
| `elephant.png` | `public/elephant.png` | 640 x 640 | `9caa818cdde183d09c56b2f56d4a26b9e54fb78074040be0c819cff91c11c098` |

Unchanged files give the same similarities as Google's demo for the same
model and delegate. The gallery's preparer, `tool/gallery_builder`, copies
them into the app's samples whenever a build bundles Image Embedder.

# Video clips

The live pages' video file mode plays `scene.mp4`, and the journey test checks
a file's rotation with `rotated.mp4`. Both are made by
[`tool/make_sample_clip.py`](../tool/make_sample_clip.py) with ffmpeg from
three photos the repository already holds as test fixtures, so they bring no
new source material:

| Photo | Fixture | Source | SHA-256 |
| --- | --- | --- | --- |
| Full-body pose | `packages/mediapipe-task-vision/test/fixtures/landmark_tasks/pose.jpg` | Google's MediaPipe test asset `https://storage.googleapis.com/mediapipe-assets/pose.jpg`, unchanged | `c8a830ed683c0276d713dd5aeda28f415f10cd6291972084a40d0d8b934ed62b` |
| Portrait | `packages/mediapipe-task-vision/test/fixtures/face_detection/landmark-ex1.jpg` | face_detection_tflite's sample, recorded in that fixture directory's README | `17a32597df503211ed126797bf8f5281f6e122545be925cfd3bf65658dc5f0ec` |
| Raised thumb | `packages/mediapipe-task-vision/test/fixtures/landmark_tasks/thumb_up.jpg` | Google's MediaPipe test asset `https://storage.googleapis.com/mediapipe-assets/thumb_up.jpg`, unchanged | `5d673c081ab13b8a1812269ff57047066f9c33c07db5f4178089e8cb3fdc0291` |

Both sources are licensed under the Apache License 2.0.

| File | Contents | Size | SHA-256 |
| --- | --- | --- | --- |
| `scene.mp4` | The three photos drifting on a 960 x 540 canvas, 3 s at 30 fps, 90 frames, H.264 main profile, 4:2:0, a keyframe every 10 frames, no audio | 451,508 bytes | `1f658dab8a782c0f21eb70daf9058a03eee1ba585c037fb95fab4466e2cfb54a` |
| `rotated.mp4` | The portrait stored a quarter turn counter-clockwise (214 x 320) and tagged to be shown a quarter turn clockwise, as a phone records portrait video; 1 s at 10 fps, 10 frames | 15,896 bytes | `9fe9c66d20b3c44bbed7456cd4d0d34a7b719f7cba645f42f55eeb15d4b2e1bc` |

H.264 at main profile decodes on every platform and browser the gallery runs
on, and frequent keyframes keep a browser's frame-by-frame seeking cheap. The
script strips encoder names and dates, so a rerun with the same ffmpeg writes
the same bytes. The preparer, `tool/gallery_builder`, copies both clips into
every build's samples, as it does the photos.
