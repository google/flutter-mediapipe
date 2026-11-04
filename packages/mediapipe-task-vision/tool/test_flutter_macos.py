"""Generate an isolated Flutter host and test macOS release-mode native bundling."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys

PACKAGE = Path(__file__).resolve().parents[1]
APP = PACKAGE.parents[1] / "build/flutter_vision_smoke"
sys.path.insert(0, str(PACKAGE.parent / "mediapipe-core/tool"))
from consumer_packages import configure_macos, consumer_environment, core_hook_defines  # noqa: E402


def test_app(app=APP, package=PACKAGE):
    env = consumer_environment()

    def run(args):
        subprocess.run(args, cwd=app, env=env, check=True)

    if not (app / ".metadata").exists():
        subprocess.run([
            "flutter", "create", "--platforms=macos", "--empty", "--no-pub",
            "--project-name", "mediapipe_vision_smoke", str(app),
        ], env=env, check=True)
    dependency = json.dumps(os.path.relpath(package, app))
    core = json.dumps(os.path.relpath(Path(package).parent / "mediapipe-core", app))
    (app / "pubspec.yaml").write_text(f"""name: mediapipe_vision_smoke
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision:
    path: {dependency}
dependency_overrides:
  mediapipe_core:
    path: {core}
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
flutter:
  assets:
    - assets/model.tflite
    - assets/face_landmarker.task
    - assets/portrait.rgb
""" + (f"hooks:\n  user_defines:\n{defines}"
       if (defines := core_hook_defines()) else ""))
    (app / "assets").mkdir(exist_ok=True)
    shutil.copyfile(PACKAGE / "models/blaze_face_short_range.tflite",
                    app / "assets/model.tflite")
    shutil.copyfile(PACKAGE / "models/face_landmarker.task",
                    app / "assets/face_landmarker.task")
    shutil.copyfile(PACKAGE / "test/fixtures/face_detection/portrait-301x209.rgb",
                    app / "assets/portrait.rgb")
    (app / "integration_test").mkdir(exist_ok=True)
    # The CPU only, as on Linux and Windows: macOS withdraws the GPU while
    # Google's library since 1.1.1 gives different Metal results from its wheel
    # (upstream-issues.md UP-057).
    for source, destination in [
            ("flutter_smoke_test.dart.template",
             "integration_test/face_detector_test.dart"),
            ("flutter_release_smoke.dart.template", "lib/main.dart")]:
        (app / destination).write_text(
            (PACKAGE / "tool" / source).read_text().replace(
                "Delegate.values", "const [Delegate.cpu]"))
    configure_macos(app)
    run(["flutter", "pub", "get"])
    run(["flutter", "test", "-d", "macos",
         "integration_test/face_detector_test.dart", "--reporter", "expanded"])
    run(["flutter", "build", "macos", "--release"])
    executable = app / ("build/macos/Build/Products/Release/"
                        "mediapipe_vision_smoke.app/Contents/MacOS/mediapipe_vision_smoke")
    subprocess.run([str(executable)], cwd=app, env=env, check=True, timeout=60)


if __name__ == "__main__":
    test_app()
