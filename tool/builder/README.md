# Flutter MediaPipe builder

Helper utility which performs build or CI/CD step operations necessary to develop, release, and use `flutter-mediapipe`.

### Usage:

Usage depends on which task you need to accomplish. All supported workflows are described below.

#### Header aggregation

Header files across all tasks in `google/flutter-mediapipe` have to stay in sync with their origin, `google/mediapipe`. To
resync these files, check out both repositories on the same machine (ideally next to each other on the file system) and run:

```sh
$ dart tool/builder/bin/main.dart headers
```

--

Check back in the future for any additional development workflows this command may support.