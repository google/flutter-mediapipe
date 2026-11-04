"""Generate independent GPU references on the machine that runs the Dart tests.

Does not change checked-in goldens, models, task code or test tolerances.
The default creates an isolated Python environment from the host's checksum-pinned
wheel (core's referenceWheels: Metal on macOS arm64, OpenGL ES on Linux x64).
--python reuses an existing environment; the generators still verify its native
library, runtime version, model digests and input fixture bytes.
"""

import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

PACKAGE = Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[1]
sys.path.insert(0, str(REPO / "packages/mediapipe-core/tool"))
from consumer_packages import core_hook_defines  # noqa: E402
from official_wheels import pinned_venv, reference_wheel  # noqa: E402
from tool_helpers import digest  # noqa: E402

FACE_TASKS = (("face_detector", "face_detection"),
              ("face_landmarker", "face_landmarker"))
FACE_FILES = (
    "face_detection/official_gpu_reference.json",
    "face_detection/official_gpu_video_reference.json",
    "face_landmarker/official_gpu_reference.json",
)
# Every suite reading a GPU reference under MEDIAPIPE_GPU_REFERENCE_DIR needs
# its references generated here; a missing one fails the suite at load time.
OBJECT_TASKS = (("object_detector", "object_detection"),)
OBJECT_FILES = (
    "object_detection/official_gpu_reference.json",
    "object_detection/official_gpu_video_reference.json",
)
# Hand Landmarker alone (--hand), or with Gesture, Pose and Holistic
# (--landmark-tasks), from the shared landmark generator.
HAND_TASKS = (("landmark_tasks", "landmark_tasks"),)
HAND_FILES = ("landmark_tasks/official_gpu_reference.json",)
# Image Classifier and Image Embedder; Image Segmenter (IMAGE mode on GPU).
IMAGE_TASKS = (("image_tasks", "image_tasks"),)
IMAGE_FILES = ("image_tasks/official_gpu_reference.json",)
SEGMENTER_TASKS = (("segmenter_tasks", "segmenter_tasks"),)
SEGMENTER_FILES = ("segmenter_tasks/official_gpu_reference.json",)
# The same tasks' CPU references, for a --test root whose suites also run
# their CPU cases: the wheel's CPU output drifts between hosts.
CPU_REFERENCES = {
    "object": ([("object_detector", "object_detection")],
               ["object_detection/official_reference.json",
                "object_detection/official_video_reference.json"]),
    "landmark": ([("landmark_tasks", "landmark_tasks")],
                 ["landmark_tasks/official_reference.json"]),
    "image": ([("image_tasks", "image_tasks")], ["image_tasks/official_reference.json"]),
    "segmenter": ([("segmenter_tasks", "segmenter_tasks")],
                  ["segmenter_tasks/official_reference.json"]),
}


def difference(reference, current):
    """Record host differences in the official API, never adjust expectations."""
    groups = {}
    structural = []

    def visit(old, new, path):
        if isinstance(old, dict) and isinstance(new, dict):
            if old.keys() != new.keys():
                structural.append(path + ": object keys differ")
            for key in old.keys() & new.keys():
                visit(old[key], new[key], path + "." + key)
        elif isinstance(old, list) and isinstance(new, list):
            if len(old) != len(new):
                structural.append(path + ": list length differs")
            for i, (left, right) in enumerate(zip(old, new)):
                visit(left, right, f"{path}[{i}]")
        elif isinstance(old, (int, float)) and not isinstance(old, bool):
            if not isinstance(new, (int, float)):
                structural.append(path + ": numeric type differs")
                return
            group = next((name for name in (
                "face_landmarks", "face_blendshapes",
                "facial_transformation_matrixes", "bounding_box",
                "keypoints", "categories", "hand_world_landmarks",
                "hand_landmarks", "handedness",
            ) if "." + name in path), "other")
            error = abs(old - new)
            item = groups.setdefault(group, {"maximum_absolute_error": 0.0,
                                             "values": 0, "path": None})
            item["values"] += 1
            if error > item["maximum_absolute_error"]:
                item.update(maximum_absolute_error=error, path=path,
                            checked_in=old, same_host=new)
        elif old != new:
            structural.append(path + ": value differs")

    visit(reference["cases"], current["cases"], "cases")
    return {"numeric_groups": groups, "structural_differences": structural}


def test_root(destination, groups):
    """Builds a root package for the Dart suites of the face tasks and [groups]
    (object, hand, landmark, image, segmenter).

    Only the root package's user_defines reach a build hook, so an isolated
    root selects exactly these tasks, and a local library folder when
    MEDIAPIPE_ASSET_SOURCE names one. On macOS the other tasks' suites run
    through test_macos_references.py.
    """
    if destination.exists():
        shutil.rmtree(destination)
    (destination / "test").mkdir(parents=True)
    folders = ["support", "fixtures/face_detection", "fixtures/face_landmarker"]
    tests = ["face_detector_test.dart", "face_landmarker_test.dart"]
    models = ["blaze_face_short_range.tflite", "face_landmarker.task"]
    tasks = ["face_detector", "face_landmarker"]
    if "object" in groups:
        folders.append("fixtures/object_detection")
        tests.append("object_detector_test.dart")
        models.append("efficientdet_lite0.tflite")
        tasks.append("object_detector")
    if "hand" in groups or "landmark" in groups:
        folders.append("fixtures/landmark_tasks")
        tests.append("landmark_tasks_test.dart")
        models.append("hand_landmarker.task")
        tasks.append("hand_landmarker")
    if "landmark" in groups:
        models += ["gesture_recognizer.task", "pose_landmarker_lite.task",
                   "holistic_landmarker.task"]
        tasks += ["gesture_recognizer", "pose_landmarker", "holistic_landmarker"]
    if "image" in groups:
        folders.append("fixtures/image_tasks")
        tests.append("image_tasks_test.dart")
        models += ["efficientnet_lite0.tflite", "mobilenet_v3_small.tflite"]
        tasks += ["image_classifier", "image_embedder"]
    if "segmenter" in groups:
        folders.append("fixtures/segmenter_tasks")
        tests.append("segmenter_tasks_test.dart")
        models += ["deeplab_v3.tflite"]
        tasks += ["image_segmenter"]
    for folder in folders:
        shutil.copytree(PACKAGE / "test" / folder, destination / "test" / folder)
    for name in tests:
        shutil.copyfile(PACKAGE / "test" / name, destination / "test" / name)
    (destination / "models").mkdir()
    for name in models:
        shutil.copyfile(PACKAGE / "models" / name, destination / "models" / name)
    (destination / "pubspec.yaml").write_text(f"""name: mediapipe_gpu_face_tests
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  mediapipe_vision:
    path: {PACKAGE}
dependency_overrides:
  mediapipe_core:
    path: {PACKAGE.parent / 'mediapipe-core'}
dev_dependencies:
  crypto: ^3.0.6
  test: ^1.31.0
hooks:
  user_defines:
{core_hook_defines()}    mediapipe_vision:
      tasks: [{", ".join(tasks)}]
""")
    return destination, ["test/" + name for name in tests]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python", type=Path,
                        help="Existing Python with this host's pinned MediaPipe")
    parser.add_argument("--output-dir", type=Path, default=REPO / "build/gpu-reference")
    parser.add_argument("--test", action="store_true",
                        help="Also run both Dart face suites with these references")
    # Opt-in because the public-runtime comparison job downloads face models only.
    parser.add_argument("--object-detector", action="store_true",
                        help="Also generate Object Detector references, for a "
                             "checkout whose object detection model is present")
    parser.add_argument("--hand", action="store_true",
                        help="Also generate Hand Landmarker references, for a "
                             "checkout whose hand model is present")
    parser.add_argument("--landmark-tasks", action="store_true",
                        help="Also generate Hand, Gesture and Pose Landmarker "
                             "references (Holistic has no GPU path, UP-026)")
    parser.add_argument("--image-tasks", action="store_true",
                        help="Also generate Image Classifier and Embedder references")
    parser.add_argument("--segmenter-tasks", action="store_true",
                        help="Also generate Image Segmenter references (IMAGE mode)")
    args = parser.parse_args()
    groups = {name for name, selected in [
        ("object", args.object_detector), ("hand", args.hand),
        ("landmark", args.landmark_tasks), ("image", args.image_tasks),
        ("segmenter", args.segmenter_tasks)] if selected}
    landmarks = bool(groups & {"hand", "landmark"})
    tasks = (FACE_TASKS + (OBJECT_TASKS if "object" in groups else ())
             + (HAND_TASKS if landmarks else ())
             + (IMAGE_TASKS if "image" in groups else ())
             + (SEGMENTER_TASKS if "segmenter" in groups else ()))
    files = (FACE_FILES + (OBJECT_FILES if "object" in groups else ())
             + (HAND_FILES if landmarks else ())
             + (IMAGE_FILES if "image" in groups else ())
             + (SEGMENTER_FILES if "segmenter" in groups else ()))
    # The tasks the package offers on this GPU: no Holistic on either (its
    # blendshapes model does not open on GPU, UP-026), no embedder or Face
    # Detector on Linux (aborts, UP-027; no LiteRT GPU plugin, UP-046), and
    # Pose without masks (Metal fails, UP-028; OpenGL ES returns 8-bit RGBA
    # masks, UP-030).
    from cpu_reference import host_target as _host
    on_metal = _host() == "macos/arm64"
    generator_arguments = {
        "landmark_tasks": ["--tasks", "hand,gesture,pose" if "landmark" in groups else "hand",
                           "--no-pose-masks"],
        "image_tasks": ["--tasks", "classifier,embedder" if on_metal else "classifier"],
    }
    # Imported here: cpu_reference imports this module for difference().
    from cpu_reference import host_target, wheel_pin
    target = host_target()
    if target not in ("macos/arm64", "linux/x64"):
        raise SystemExit("GPU references require macOS arm64 or Linux x64.")
    if args.test and groups - {"object"} and target != "linux/x64":
        raise SystemExit("On macOS, run these tasks' suites with "
                         "tool/test_macos_references.py.")
    wheel_url, wheel_sha256, library_sha256, version = wheel_pin(target)
    metal = target == "macos/arm64"
    # Face Detector's GPU runs on LiteRT since 1.1.0, and Google's Linux
    # library lacks LiteRT's GPU plugin (UP-046): the package withdraws that
    # GPU there, and the Face Detector suite checks the refusal instead.
    if not metal:
        tasks = tuple(task for task in tasks if task[0] != "face_detector")
        files = tuple(name for name in files
                      if not name.startswith("face_detection/"))
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Do not leave a stale receipt if generation or model verification fails.
    provenance = output / "provenance.json"
    if provenance.exists():
        provenance.unlink()
    python = args.python
    if python is None:
        python = pinned_venv(REPO / "build/ci-tmp/gpu-reference-env", reference_wheel(target))
    python = python.absolute()
    env = {**os.environ, "MPLCONFIGDIR": str(output / "matplotlib")}
    summaries = {}
    graphics = {}
    for task, folder in tasks:
        log_file = output / (task + ".log")
        command = [str(python), "-B", str(PACKAGE / "tool" /
                   f"generate_{task}_reference.py"), "--delegate", "gpu",
                   "--output-dir", str(output / folder),
                   *generator_arguments.get(task, [])]
        with log_file.open("w") as log:
            result = subprocess.run(command, env=env, stdout=log,
                                    stderr=subprocess.STDOUT)
        log = log_file.read_text()
        print("\n".join(log.splitlines()[-12:]), flush=True)
        result.check_returncode()
        graphics[task] = sorted(set(re.findall(r"GL version:.*", log)))
        # 1.0.x runs inference on TensorFlow Lite's Metal delegate; 1.1.0's
        # LiteRT GPU accelerator logs the Metal API it initializes instead.
        if metal and not any(line in log for line in (
                "Created TensorFlow Lite delegate for Metal.",
                "Initializing Metal-based API from graph.")):
            raise RuntimeError(f"Official {task} did not confirm Metal creation")
        # Linux tasks run inference through TensorFlow Lite's OpenGL ES backend
        # directly (use_advanced_gpu_api), so no delegate line is logged; the
        # created context is the confirmation.
        if not metal and not any("OpenGL ES" in line for line in graphics[task]):
            raise RuntimeError(f"Official {task} did not create an OpenGL ES context")
    for name in files:
        baseline = PACKAGE / "test/fixtures" / name
        reference = json.loads((output / name).read_text())
        # Only the Mac face, hand and object GPU references are checked in.
        summaries[name] = (difference(json.loads(baseline.read_text()), reference)
                           if baseline.exists() else "no checked-in GPU reference")
    report = {
        "source": "official-python-api", "runtime": "mediapipe==" + version,
        "library_sha256": library_sha256,
        "wheel_url": wheel_url, "wheel_sha256": wheel_sha256,
        "delegate": "GPU", ("metal_confirmed" if metal else "gl_confirmed"): True,
        "os": platform.platform(), "machine": platform.machine(),
        "graphics": graphics, "files": {name: digest(output / name) for name in files},
        "checked_in_reference_differences": summaries,
        "scope": "Official wheel on this host versus checked-in physical-Mac "
                 "GPU references. Dart tests separately compare the native task "
                 "with these independently generated outputs.",
        **({} if metal else {"renderer_override": os.environ.get("force_gl_renderer")}),
    }
    provenance.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summaries, indent=2), flush=True)
    print(f"Verified official GPU references: {output}", flush=True)
    if args.test:
        env["MEDIAPIPE_GPU_REFERENCE_DIR"] = str(output)
        root, suites = test_root(REPO / "build/gpu-face-tests", groups)
        if "hand" in groups and "landmark" not in groups:
            env["MEDIAPIPE_LANDMARK_TASKS"] = "hand"
        if groups - {"hand"}:
            # These suites run their CPU cases too; compare those, and the
            # face suites' (which then read this directory), with the wheel
            # on this host as well.
            from cpu_reference import FACE_FILES as CPU_FACE_FILES
            from cpu_reference import FACE_TASKS as CPU_FACE_TASKS
            from cpu_reference import generate
            cpu_tasks = list(CPU_FACE_TASKS) + [
                task for group in sorted(groups & CPU_REFERENCES.keys())
                for task in CPU_REFERENCES[group][0]]
            cpu_files = list(CPU_FACE_FILES) + [
                name for group in sorted(groups & CPU_REFERENCES.keys())
                for name in CPU_REFERENCES[group][1]]
            cpu = REPO / "build/gpu-job-cpu-reference"
            generate(cpu, cpu, target, cpu_tasks, cpu_files, python=python)
            env["MEDIAPIPE_CPU_REFERENCE_DIR"] = str(cpu)
        with (output / "dart-tests.log").open("w") as log:
            result = subprocess.run(["dart", "pub", "get"], cwd=root, env=env,
                                    stdout=log, stderr=subprocess.STDOUT)
            if result.returncode == 0:
                result = subprocess.run([
                    "dart", "test", *suites, "--reporter", "expanded",
                ], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
        print("\n".join((output / "dart-tests.log").read_text().splitlines()[-30:]),
              flush=True)
        result.check_returncode()


if __name__ == "__main__":
    main()
